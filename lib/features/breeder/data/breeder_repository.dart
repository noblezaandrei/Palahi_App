import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/breeder_model.dart';

final breederRepositoryProvider = Provider<BreederRepository>((ref) {
  return BreederRepository(FirebaseFirestore.instance);
});

final breedersStreamProvider = StreamProvider<List<BreederModel>>((ref) {
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
}
