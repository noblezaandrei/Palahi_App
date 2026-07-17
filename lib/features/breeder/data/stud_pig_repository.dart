import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/stud_pig_model.dart';

final studPigRepositoryProvider = Provider<StudPigRepository>((ref) {
  return StudPigRepository(FirebaseFirestore.instance);
});

final breederStudPigsProvider = StreamProvider.family<List<StudPigModel>, String>((ref, breederId) {
  return ref.watch(studPigRepositoryProvider).getStudPigsForBreeder(breederId);
});

final allAvailablePigsProvider = StreamProvider<List<StudPigModel>>((ref) {
  return ref.watch(studPigRepositoryProvider).getAllAvailableStudPigs();
});

class StudPigRepository {
  final FirebaseFirestore _firestore;

  StudPigRepository(this._firestore);

  Stream<List<StudPigModel>> getStudPigsForBreeder(String breederId) {
    return _firestore
        .collection('stud_pigs')
        .where('breederId', isEqualTo: breederId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => StudPigModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<StudPigModel>> getAllAvailableStudPigs() {
    return _firestore
        .collection('stud_pigs')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => StudPigModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> saveStudPig(StudPigModel pig) async {
    final docRef = pig.id.isEmpty
        ? _firestore.collection('stud_pigs').doc()
        : _firestore.collection('stud_pigs').doc(pig.id);
    
    await docRef.set(pig.toJson());
  }

  Future<void> deleteStudPig(String pigId) async {
    await _firestore.collection('stud_pigs').doc(pigId).delete();
  }
}
