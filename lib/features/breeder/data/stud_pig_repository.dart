import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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

  /// Deletes a stud pig and cleans up its image file in Firebase Storage.
  Future<void> deleteStudPig(String pigId) async {
    try {
      final doc = await _firestore.collection('stud_pigs').doc(pigId).get();
      if (doc.exists) {
        final imageUrl = doc.data()?['imageUrl'] as String? ?? '';
        if (imageUrl.isNotEmpty && imageUrl.contains('firebasestorage')) {
          final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await storageRef.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting pig image from storage: $e');
    }
    
    await _firestore.collection('stud_pigs').doc(pigId).delete();
  }
}
