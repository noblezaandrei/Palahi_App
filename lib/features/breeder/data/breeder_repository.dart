import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/breeder_model.dart';
import '../../auth/data/auth_repository.dart';

final breederRepositoryProvider = Provider<BreederRepository>((ref) {
  return BreederRepository(FirebaseFirestore.instance);
});

final breedersStreamProvider = StreamProvider<List<BreederModel>>((ref) {
  // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
  // a permission-denied error during logout stays cached empty forever.
  ref.watch(authStateProvider);
  return ref.watch(breederRepositoryProvider).getBreeders();
});

class BreederRepository {
  final FirebaseFirestore _firestore;

  BreederRepository(this._firestore);

  Stream<List<BreederModel>> getBreeders() async* {
    try {
      await for (final snapshot
          in _firestore.collection('breeders').snapshots()) {
        yield snapshot.docs
            .map((doc) => BreederModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load breeders: $error');
      yield <BreederModel>[];
    }
  }

  Future<void> addBreeder(BreederModel breeder) async {
    await _firestore
        .collection('breeders')
        .doc(breeder.id)
        .set(breeder.toJson());
  }

  Future<void> updateAvailableDates(
    String breederId,
    List<String> availableDates,
  ) async {
    await _firestore.collection('breeders').doc(breederId).update({
      'availableDates': availableDates,
    });
  }
}
