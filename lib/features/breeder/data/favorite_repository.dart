import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(FirebaseFirestore.instance);
});

// Provides a list of favorited breeder IDs for the current user
final userFavoritesProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(favoriteRepositoryProvider).getUserFavorites(user.uid);
});

class FavoriteRepository {
  final FirebaseFirestore _firestore;

  FavoriteRepository(this._firestore);

  Stream<List<String>> getUserFavorites(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()['breederId'] as String).toList();
    });
  }

  Future<void> toggleFavorite(String userId, String breederId, bool isCurrentlyFavorited) async {
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
