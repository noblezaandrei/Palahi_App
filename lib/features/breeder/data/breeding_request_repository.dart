import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/breeding_request_model.dart';

final breedingRequestRepositoryProvider = Provider<BreedingRequestRepository>((ref) {
  return BreedingRequestRepository(FirebaseFirestore.instance);
});

// For Farmers tracking their requests
final farmerRequestsProvider = StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
  return ref.watch(breedingRequestRepositoryProvider).getRequestsForFarmer(farmerId);
});

// For Breeders managing incoming requests
final breederRequestsProvider = StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
  return ref.watch(breedingRequestRepositoryProvider).getRequestsForBreeder(breederId);
});

class BreedingRequestRepository {
  final FirebaseFirestore _firestore;

  BreedingRequestRepository(this._firestore);

  Stream<List<BreedingRequestModel>> getRequestsForFarmer(String farmerId) {
    return _firestore
        .collection('breeding_requests')
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<BreedingRequestModel>> getRequestsForBreeder(String breederId) {
    return _firestore
        .collection('breeding_requests')
        .where('breederId', isEqualTo: breederId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> sendRequest(BreedingRequestModel request) async {
    await _firestore.collection('breeding_requests').add(request.toJson());
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await _firestore.collection('breeding_requests').doc(requestId).update({'status': status});
  }
}
