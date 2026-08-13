import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  Stream<List<BreedingRequestModel>> getRequestsForFarmer(
    String farmerId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('farmerId', isEqualTo: farmerId)
              .orderBy('createdAt', descending: true)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load farmer requests: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Stream<List<BreedingRequestModel>> getRequestsForBreeder(
    String breederId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('breederId', isEqualTo: breederId)
              .orderBy('createdAt', descending: true)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load breeder requests: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Stream<List<BreedingRequestModel>> getCompletedRequestsForBreeder(
    String breederId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('breederId', isEqualTo: breederId)
              .where('status', isEqualTo: 'completed')
              .orderBy('createdAt', descending: true)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load completed breeder requests: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Stream<List<BreedingRequestModel>> getCompletedRequestsForFarmer(
    String farmerId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('farmerId', isEqualTo: farmerId)
              .where('status', isEqualTo: 'completed')
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load completed farmer requests: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Stream<List<BreedingRequestModel>> getPendingRequestsForFarmer(
    String farmerId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('farmerId', isEqualTo: farmerId)
              .where('status', isEqualTo: 'pending')
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load pending farmer requests: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Future<void> sendRequest(BreedingRequestModel request) async {
    try {
      await _firestore.collection('bookings').add(request.toJson());
    } catch (e) {
      debugPrint('Failed to add booking document: $e');
      debugPrint('Booking payload: ${request.toJson()}');
      rethrow;
    }

    try {
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
    } catch (e) {
      debugPrint('Failed to create booking notification: $e');
    }
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
    String notifyUserId = '';

    switch (status) {
      case 'accepted':
        notifyUserId = booking['farmerId'] as String? ?? '';
        title = 'Booking Accepted';
        body =
            '${booking['breederName']} accepted your booking for ${booking['studPigName']}.';
        break;

      case 'rejected':
        notifyUserId = booking['farmerId'] as String? ?? '';
        title = 'Booking Rejected';
        body =
            '${booking['breederName']} rejected your booking for ${booking['studPigName']}.';
        break;

      case 'done_breeding':
        notifyUserId = booking['breederId'] as String? ?? '';
        title = 'Breeding Finished';
        body =
            '${booking['farmerName']} marked breeding for ${booking['studPigName']} as Done. Awaiting cash payment.';
        break;

      case 'completed':
        notifyUserId = booking['farmerId'] as String? ?? '';
        title = 'Breeding Completed & Paid';
        body =
            '${booking['breederName']} confirmed receipt of cash payment for ${booking['studPigName']}. Please rate and review the service.';
        break;

      case 'cancelled':
        // Notify the opposite party
        notifyUserId = booking['farmerId'] as String? ?? '';
        title = 'Booking Cancelled';
        body = 'Your booking for ${booking['studPigName']} was cancelled.';
        break;
    }

    if (title.isNotEmpty && notifyUserId.isNotEmpty) {
      await _firestore
          .collection('notifications')
          .add(
            NotificationModel(
              id: '',
              userId: notifyUserId,
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
