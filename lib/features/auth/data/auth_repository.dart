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

  /// Firebase Auth has no concept of a username — it only authenticates by
  /// email — so signing in with one means resolving it to the account's
  /// email first, via the public /usernames lookup.
  ///
  /// Anything containing '@' is treated as an email and passed straight
  /// through. That's what keeps accounts created before usernames existed
  /// able to sign in, and it's why usernames themselves can't contain '@'.
  Future<String> resolveToEmail(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) return trimmed;

    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(trimmed.toLowerCase())
        .get();

    final email = doc.data()?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found with that username.',
      );
    }
    return email;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username.trim().toLowerCase())
        .get();
    return !doc.exists;
  }

  Future<UserCredential> signInWithUsernameOrEmail(
    String identifier,
    String password,
  ) async {
    final email = await resolveToEmail(identifier);
    return signInWithEmailAndPassword(email, password);
  }

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
    String username,
  ) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (!await isUsernameAvailable(normalizedUsername)) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'That username is already taken. Please pick another.',
      );
    }

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      // Claim the username before anything else, so that losing the race to
      // another signup costs us only a throwaway account rather than leaving
      // a live one that can never be logged into by username. Writing to
      // /usernames requires being signed in, which we now are.
      try {
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(normalizedUsername)
            .set({'uid': user.uid, 'email': email});
      } catch (error) {
        // Almost always means someone claimed the name in the gap above,
        // but a missing /usernames security rule looks identical from here,
        // so log the real error rather than silently blaming a race.
        debugPrint('Username claim failed for "$normalizedUsername": $error');
        await user.delete();
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'Could not claim that username. Please try another.',
        );
      }

      await user.sendEmailVerification();
      await _createUserProfile(
        uid: user.uid,
        email: email,
        name: name,
        role: role,
        username: username.trim(),
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

  /// [username] is null for Google sign-ups — those accounts authenticate
  /// through Google rather than by username, so they never claim one.
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role,
    String? username,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'id': uid,
      'email': email,
      'name': name,
      'role': role,
      'username': ?username,
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
  Future<void> resendVerificationEmail(
    String identifier,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: await resolveToEmail(identifier),
      password: password,
    );
    final user = userCredential.user;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
    await _auth.signOut();
  }
}
