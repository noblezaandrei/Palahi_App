import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/breeding_request_model.dart';
import '../../communication/models/notification_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/utils/error_messages.dart';

final breedingRequestRepositoryProvider = Provider<BreedingRequestRepository>((
  ref,
) {
  return BreedingRequestRepository(FirebaseFirestore.instance);
});

// For Farmers tracking their bookings
final farmerRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
      // a permission-denied error during logout stays cached empty forever.
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getRequestsForFarmer(farmerId);
    });

// For Breeders managing incoming bookings
final breederRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getRequestsForBreeder(breederId);
    });

// For completed appointments (Breeding History)
final completedRequestsForBreederProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getCompletedRequestsForBreeder(breederId);
    });

final farmerCompletedRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getCompletedRequestsForFarmer(farmerId);
    });

final farmerPendingRequestsProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getPendingRequestsForFarmer(farmerId);
    });

/// Each of the breeder's pigs mapped to the dates (yyyy-MM-dd) it's already
/// booked on, live — so the pig grid can grey out fully booked pigs.
final breederPigBookedDatesProvider =
    StreamProvider.family<Map<String, Set<String>>, String>((ref, breederId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .watchBookedDatesForBreeder(breederId);
    });

/// The /slot_locks document id for a stud pig's day — a pig breeds at most
/// once a day. Must match slotLockId() in firestore.rules.
String slotLockId(String studPigId, String date) => '${studPigId}_$date';

/// Bookings in these statuses no longer hold their day.
const _slotFreeingStatuses = ['cancelled', 'rejected'];

/// Thrown when the stud pig is already booked on the chosen day.
class SlotTakenException extends AppException {
  const SlotTakenException()
    : super(
        'Sorry, someone just booked this stud pig for that day. Please pick '
        'another date.',
      );
}

/// Statuses that are done and no longer need action — kept out of the main
/// request list and shown in the History screen instead.
const terminalBookingStatuses = ['completed', 'rejected', 'cancelled'];

// For a farmer's past (completed/rejected/cancelled) bookings.
final farmerHistoryProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, farmerId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getHistoryForFarmer(farmerId);
    });

// For a breeder's past (completed/rejected/cancelled) bookings.
final breederHistoryProvider =
    StreamProvider.family<List<BreedingRequestModel>, String>((ref, breederId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .getHistoryForBreeder(breederId);
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

  // whereIn + no orderBy avoids needing another composite index; sorted
  // client-side instead.
  Stream<List<BreedingRequestModel>> getHistoryForFarmer(
    String farmerId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('farmerId', isEqualTo: farmerId)
              .where('status', whereIn: terminalBookingStatuses)
              .snapshots()) {
        final list = snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (error) {
      debugPrint('Failed to load farmer history: $error');
      yield <BreedingRequestModel>[];
    }
  }

  Stream<List<BreedingRequestModel>> getHistoryForBreeder(
    String breederId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('bookings')
              .where('breederId', isEqualTo: breederId)
              .where('status', whereIn: terminalBookingStatuses)
              .snapshots()) {
        final list = snapshot.docs
            .map((doc) => BreedingRequestModel.fromJson(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (error) {
      debugPrint('Failed to load breeder history: $error');
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

  /// Creates the booking, its conflict-check mirror and its slot lock in one
  /// atomic write. The lock is what makes double booking impossible: if
  /// another farmer claimed the same pig and day first — even a split
  /// second earlier — the whole write is rejected and nothing is saved.
  Future<void> sendRequest(BreedingRequestModel request) async {
    final bookingRef = _firestore.collection('bookings').doc();
    final lockRef = _firestore
        .collection('slot_locks')
        .doc(slotLockId(request.studPigId, request.bookingDate));

    final batch = _firestore.batch()
      // Stamp the request time on the server so it's exact regardless of
      // the farmer's phone clock.
      ..set(bookingRef, {
        ...request.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_firestore.collection('booking_slots').doc(bookingRef.id), {
        'breederId': request.breederId,
        'studPigId': request.studPigId,
        'bookingDate': request.bookingDate,
        'bookingTime': request.bookingTime,
        'status': request.status,
      })
      ..set(lockRef, {'bookingId': bookingRef.id});

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // A taken slot is rejected as permission-denied; confirm that's the
      // reason before saying so.
      if (e.code == 'permission-denied') {
        final lock = await lockRef.get(const GetOptions(source: Source.server));
        if (lock.exists) throw const SlotTakenException();
      }
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
              referenceId: bookingRef.id,
              isRead: false,
              createdAt: DateTime.now(),
            ).toJson(),
          );
    } catch (e) {
      debugPrint('Failed to create booking notification: $e');
    }
  }

  /// The booking's current status, or null if it no longer exists.
  Future<String?> getRequestStatus(String requestId) async {
    final doc = await _firestore.collection('bookings').doc(requestId).get();
    return doc.data()?['status'] as String?;
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(requestId)
        .get();

    if (!bookingDoc.exists) return;

    final booking = bookingDoc.data()!;

    // The booking and its conflict-check mirror change together, so the
    // mirror can never be left showing a stale status.
    final batch = _firestore.batch()
      ..update(_firestore.collection('bookings').doc(requestId), {
        'status': status,
        if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
      })
      ..set(_firestore.collection('booking_slots').doc(requestId), {
        'breederId': booking['breederId'],
        'studPigId': booking['studPigId'],
        'bookingDate': booking['bookingDate'],
        'bookingTime': booking['bookingTime'],
        'status': status,
      }, SetOptions(merge: true));
    await batch.commit();

    String title = '';
    String body = '';
    String notifyUserId = '';

    // Completion and cancellation can each come from either side, and the
    // notification should go to the *other* party, not the one who acted.
    final actedByFarmer =
        FirebaseAuth.instance.currentUser?.uid == booking['farmerId'];

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
        if (actedByFarmer) {
          notifyUserId = booking['breederId'] as String? ?? '';
          title = 'Booking Completed';
          body =
              '${booking['farmerName']} confirmed the ${booking['studPigName']} booking as completed.';
        } else {
          notifyUserId = booking['farmerId'] as String? ?? '';
          title = 'Breeding Completed & Paid';
          body =
              '${booking['breederName']} confirmed receipt of cash payment for ${booking['studPigName']}. Please rate and review the service.';
        }
        break;

      case 'cancelled':
        title = 'Booking Cancelled';
        if (actedByFarmer) {
          notifyUserId = booking['breederId'] as String? ?? '';
          body =
              '${booking['farmerName']} cancelled their booking for ${booking['studPigName']}.';
        } else {
          notifyUserId = booking['farmerId'] as String? ?? '';
          body = 'Your booking for ${booking['studPigName']} was cancelled.';
        }
        break;
    }

    // The status change already succeeded; a failed notification shouldn't
    // be reported to the user as a failed update.
    if (title.isNotEmpty && notifyUserId.isNotEmpty) {
      try {
        await _firestore
            .collection('notifications')
            .add(
              NotificationModel(
                id: '',
                userId: notifyUserId,
                title: title,
                body: body,
                type: 'booking',
                referenceId: requestId,
                isRead: false,
                createdAt: DateTime.now(),
              ).toJson(),
            );
      } catch (e) {
        debugPrint('Failed to create status notification: $e');
      }
    }
  }

  /// Checks if the stud pig is already booked on [date] — a pig breeds at
  /// most once a day. Every status except cancelled/rejected holds the day,
  /// including done_breeding.
  ///
  /// This gives the farmer a friendly answer up front; the slot lock in
  /// [sendRequest] is what actually guarantees no double booking. It reads
  /// from the server (never the offline cache, which could be stale), so
  /// offline it fails instead of queueing a booking that may be rejected.
  Future<bool> checkBookingConflict(String studPigId, String date) async {
    final query = await _firestore
        .collection('booking_slots')
        .where('studPigId', isEqualTo: studPigId)
        .where('bookingDate', isEqualTo: date)
        .get(const GetOptions(source: Source.server));

    return query.docs.any((doc) {
      final status = doc.data()['status'] as String? ?? '';
      return !_slotFreeingStatuses.contains(status);
    });
  }

  /// The dates (yyyy-MM-dd) the stud pig is already booked on, so the date
  /// picker can grey them out. Read from the server for the same reason as
  /// [checkBookingConflict].
  Future<Set<String>> getBookedDatesForPig(String studPigId) async {
    final query = await _firestore
        .collection('booking_slots')
        .where('studPigId', isEqualTo: studPigId)
        .get(const GetOptions(source: Source.server));

    return {
      for (final doc in query.docs)
        if (!_slotFreeingStatuses.contains(doc.data()['status'] ?? ''))
          doc.data()['bookingDate'] as String? ?? '',
    }..remove('');
  }

  /// Live version of [getBookedDatesForPig] for all of a breeder's pigs at
  /// once, keyed by stud pig id. Only for display; booking still re-checks
  /// on the server.
  Stream<Map<String, Set<String>>> watchBookedDatesForBreeder(
    String breederId,
  ) {
    return _firestore
        .collection('booking_slots')
        .where('breederId', isEqualTo: breederId)
        .snapshots()
        .map((snapshot) {
          final bookedDates = <String, Set<String>>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final pigId = data['studPigId'] as String? ?? '';
            final date = data['bookingDate'] as String? ?? '';
            if (pigId.isEmpty ||
                date.isEmpty ||
                _slotFreeingStatuses.contains(data['status'] ?? '')) {
              continue;
            }
            bookedDates.putIfAbsent(pigId, () => {}).add(date);
          }
          return bookedDates;
        });
  }
}
