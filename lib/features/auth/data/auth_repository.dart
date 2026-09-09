import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Stream<Map<String, dynamic>?> safeUserProfileStream(
  Stream<Map<String, dynamic>?> stream,
) async* {
  try {
    await for (final value in stream) {
      yield value;
    }
  } catch (error) {
    debugPrint('User profile unavailable: $error');
    yield null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream<Map<String, dynamic>?>.empty();
      return safeUserProfileStream(
        ref.read(authRepositoryProvider).getUserProfileStream(user.uid),
      );
    },
    loading: () => const Stream<Map<String, dynamic>?>.empty(),
    error: (err, stack) => Stream.value(null),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      // Refresh cached user data so we see the latest emailVerified status.
      await user.reload();
      if (!_auth.currentUser!.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Please verify your email before logging in. Check your inbox for the verification link.',
        );
      }
    }

    return userCredential;
  }

  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    String role,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      await userCredential.user!.sendEmailVerification();
      await _createUserProfile(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
      );
    }

    return userCredential;
  }

  /// Signs in with Google via Firebase's built-in provider flow (works on
  /// web, Android and iOS without a separate google_sign_in dependency).
  /// Google accounts are already verified, so there's no email-verification
  /// gate here like there is for password sign-in.
  Future<UserCredential> signInWithGoogle() {
    // Force the account chooser every time — without this, Google silently
    // reuses the browser's existing session instead of letting the user
    // pick which account to sign in with.
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    // signInWithProvider() isn't implemented for Flutter web in this
    // firebase_auth version — web needs the popup flow instead.
    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }
    return _auth.signInWithProvider(provider);
  }

  /// Whether this uid already has a `users` profile document — false right
  /// after a brand-new Google sign-in, since Google doesn't know their role.
  Future<bool> hasUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists;
  }

  /// Finishes account setup for a first-time Google sign-in once the user
  /// has picked their role.
  Future<void> completeGoogleSignUp({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) {
    return _createUserProfile(uid: uid, email: email, name: name, role: role);
  }

  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'id': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (role == 'breeder') {
      await FirebaseFirestore.instance.collection('breeders').doc(uid).set({
        'userId': uid,
        'farmName': "$name's Farm",
        'location': 'Not specified yet',
        'coordinates': const GeoPoint(
          14.5995,
          120.9842,
        ), // Default coordinates (Manila)
        'rating': 0.0,
        'reviewCount': 0,
        'imageUrl': '',
        'about': 'Welcome to my breeder farm!',
        'services': [
          'Natural Breeding',
          'Artificial Insemination',
        ], // Both by default
      });
    }
  }

  // Helper method to fetch the current user's profile from Firestore (One-time)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }

  // Real-time stream of the user profile
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Signs in just long enough to resend the verification email, then signs
  // back out, since Firebase only allows sending it to the signed-in user.
  Future<void> resendVerificationEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
    await _auth.signOut();
  }
}
