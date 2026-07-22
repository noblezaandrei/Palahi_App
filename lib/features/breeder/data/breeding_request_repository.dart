import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/breeding_request_model.dart';

final breedingRequestRepositoryProvider = Provider<BreedingRequestRepository>((ref) {
  return BreedingRequestRepository(FirebaseFirestore.instance);
});

// For Farmers tracking their bookings
final farmerRequestsProvider = StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
  return ref.watch(breedingRequestRepositoryProvider).getRequestsForFarmer(farmerId);
});

// For Breeders managing incoming bookings
final breederRequestsProvider = StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
  return ref.watch(breedingRequestRepositoryProvider).getRequestsForBreeder(breederId);
});

// For completed appointments (Breeding History)
final completedRequestsForBreederProvider = StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
  return ref.watch(breedingRequestRepositoryProvider).getCompletedRequestsForBreeder(breederId);
});

class BreedingRequestRepository {
  final FirebaseFirestore _firestore;

  BreedingRequestRepository(this._firestore);

  Stream<List<BreedingRequestModel>> getRequestsForFarmer(String farmerId) {
    return _firestore
        .collection('bookings')
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<BreedingRequestModel>> getRequestsForBreeder(String breederId) {
    return _firestore
        .collection('bookings')
        .where('breederId', isEqualTo: breederId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<BreedingRequestModel>> getCompletedRequestsForBreeder(String breederId) {
    return _firestore
        .collection('bookings')
        .where('breederId', isEqualTo: breederId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> sendRequest(BreedingRequestModel request) async {
    await _firestore.collection('bookings').add(request.toJson());
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    if (status == 'completed') {
      await _firestore.collection('bookings').doc(requestId).update({
        'status': status,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('bookings').doc(requestId).update({'status': status});
    }
  }

  /// Checks if the pig is already booked for the exact date and time.
  /// Prevents double booking if the existing booking is active (pending, accepted, or completed).
  Future<bool> checkBookingConflict(String pigId, String date, String time) async {
    final query = await _firestore
        .collection('bookings')
        .where('studPigId', isEqualTo: pigId)
        .where('bookingDate', isEqualTo: date)
        .where('bookingTime', isEqualTo: time)
        .get();

    return query.docs.any((doc) {
      final status = doc.data()['status'] as String? ?? '';
      return status == 'pending' || status == 'accepted' || status == 'completed';
    });
  }
}
