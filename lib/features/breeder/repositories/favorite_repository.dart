import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(FirebaseFirestore.instance);
});

// Provides a list of favorited breeder IDs for the current user
final userFavoritesProvider = StreamProvider<List<String>>((ref) {
  // Watch the auth stream itself (not just currentUser) so this provider
  // actually rebuilds and re-subscribes on sign-in/out, rather than
  // permanently caching whatever user happened to be signed in when this
  // provider was first created.
  final user = ref
      .watch(authStateProvider)
      .maybeWhen(data: (user) => user, orElse: () => null);
  if (user == null) return Stream.value([]);

  return ref.watch(favoriteRepositoryProvider).getUserFavorites(user.uid);
});

class FavoriteRepository {
  final FirebaseFirestore _firestore;

  FavoriteRepository(this._firestore);

  Stream<List<String>> getUserFavorites(String userId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('favorites')
              .where('userId', isEqualTo: userId)
              .snapshots()) {
        // whereType skips a malformed doc instead of crashing the whole list
        // on a hard `as String` cast.
        yield snapshot.docs
            .map((doc) => doc.data()['breederId'])
            .whereType<String>()
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load favorites: $error');
      yield <String>[];
    }
  }

  Future<void> toggleFavorite(
    String userId,
    String breederId,
    bool isCurrentlyFavorited,
  ) async {
    final query = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('breederId', isEqualTo: breederId)
        .get();

    if (isCurrentlyFavorited) {
      // Remove it
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } else {
      // Add it
      if (query.docs.isEmpty) {
        await _firestore.collection('favorites').add({
          'userId': userId,
          'breederId': breederId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
