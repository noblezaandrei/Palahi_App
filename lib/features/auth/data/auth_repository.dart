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

    // Save additional user info to Firestore
    if (userCredential.user != null) {
      await userCredential.user!.sendEmailVerification();
      final uid = userCredential.user!.uid;
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

    return userCredential;
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
