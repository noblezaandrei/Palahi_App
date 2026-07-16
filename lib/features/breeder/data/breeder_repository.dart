import 'package:cloud_firestore/cloud_firestore.dart';
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

  Stream<List<BreederModel>> getBreeders() {
    return _firestore.collection('breeders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BreederModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addBreeder(BreederModel breeder) async {
    await _firestore.collection('breeders').doc(breeder.id).set(breeder.toJson());
  }
}
