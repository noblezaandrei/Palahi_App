import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (user == null) return Stream.value(null);
      return ref.read(authRepositoryProvider).getUserProfileStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmailAndPassword(String email, String password, String name, String role) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    
    // Save additional user info to Firestore
    if (userCredential.user != null) {
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'email': email,
        'name': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    return userCredential;
  }

  // Helper method to fetch the current user's profile from Firestore (One-time)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  // Real-time stream of the user profile
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((doc) => doc.data());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
