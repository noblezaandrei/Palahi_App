import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/breeding_request_model.dart';
import '../../communication/domain/models/notification_model.dart';

final breedingRequestRepositoryProvider = Provider<BreedingRequestRepository>((
  ref,
) {
  return BreedingRequestRepository(FirebaseFirestore.instance);
});

// For Farmers tracking their bookings
final farmerRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getRequestsForFarmer(farmerId);
    });

// For Breeders managing incoming bookings
final breederRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getRequestsForBreeder(breederId);
    });

// For completed appointments (Breeding History)
final completedRequestsForBreederProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getCompletedRequestsForBreeder(breederId);
    });

final farmerCompletedRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getCompletedRequestsForFarmer(farmerId);
    });

final farmerPendingRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getPendingRequestsForFarmer(farmerId);
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
          return snapshot.docs
              .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<BreedingRequestModel>> getRequestsForBreeder(String breederId) {
    return _firestore
        .collection('bookings')
        .where('breederId', isEqualTo: breederId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<BreedingRequestModel>> getCompletedRequestsForBreeder(
    String breederId,
  ) {
    return _firestore
        .collection('bookings')
        .where('breederId', isEqualTo: breederId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<BreedingRequestModel>> getCompletedRequestsForFarmer(
    String farmerId,
  ) {
    return _firestore
        .collection('bookings')
        .where('farmerId', isEqualTo: farmerId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<BreedingRequestModel>> getPendingRequestsForFarmer(
    String farmerId,
  ) {
    return _firestore
        .collection('bookings')
        .where('farmerId', isEqualTo: farmerId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> sendRequest(BreedingRequestModel request) async {
    await _firestore.collection('bookings').add(request.toJson());

    await _firestore
        .collection('notifications')
        .add(
          NotificationModel(
            id: '',
            userId: request.breederId,
            title: 'New Booking Request',
            body:
                '${request.farmerName} requested ${request.breedingType} for ${request.studPigName}.',
            type: 'booking',
            isRead: false,
            createdAt: DateTime.now(),
          ).toJson(),
        );
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(requestId)
        .get();

    if (!bookingDoc.exists) return;

    final booking = bookingDoc.data()!;

    if (status == 'completed') {
      await _firestore.collection('bookings').doc(requestId).update({
        'status': status,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('bookings').doc(requestId).update({
        'status': status,
      });
    }

    String title = '';
    String body = '';

    switch (status) {
      case 'accepted':
        title = 'Booking Accepted';
        body =
            '${booking['breederName']} accepted your booking for ${booking['studPigName']}.';
        break;

      case 'rejected':
        title = 'Booking Rejected';
        body =
            '${booking['breederName']} rejected your booking for ${booking['studPigName']}.';
        break;

      case 'completed':
        title = 'Breeding Completed';
        body =
            'Your breeding appointment for ${booking['studPigName']} has been completed.';
        break;

      case 'cancelled':
        title = 'Booking Cancelled';
        body = '${booking['breederName']} cancelled your booking.';
        break;
    }

    if (title.isNotEmpty) {
      await _firestore
          .collection('notifications')
          .add(
            NotificationModel(
              id: '',
              userId: booking['farmerId'],
              title: title,
              body: body,
              type: 'booking',
              isRead: false,
              createdAt: DateTime.now(),
            ).toJson(),
          );
    }
  }

  /// Checks if the pig is already booked for the exact date and time.
  /// Prevents double booking if the existing booking is active (pending, accepted, or completed).
  Future<bool> checkBookingConflict(
    String pigId,
    String date,
    String time,
  ) async {
    final query = await _firestore
        .collection('bookings')
        .where('studPigId', isEqualTo: pigId)
        .where('bookingDate', isEqualTo: date)
        .where('bookingTime', isEqualTo: time)
        .get();

    return query.docs.any((doc) {
      final status = doc.data()['status'] as String? ?? '';
      return status == 'pending' ||
          status == 'accepted' ||
          status == 'completed';
    });
  }
}
