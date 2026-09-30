import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/breeding_request_model.dart';
import '../../communication/models/notification_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/utils/date_utils.dart';
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

/// The hourly slots (e.g. "09:00 AM") already taken at a breeder's farm on
/// a day, across all their pigs, live — so the booking sheet can grey them
/// out the moment another farmer books one.
final breederTakenTimesProvider = StreamProvider.autoDispose
    .family<
      Set<String>,
      ({String breederId, String date, String? exceptBookingId})
    >((ref, day) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRequestRepositoryProvider)
          .watchTakenTimes(
            day.breederId,
            day.date,
            exceptBookingId: day.exceptBookingId,
          );
    });

/// The /slot_locks document id for a stud pig's day — a pig breeds at most
/// once a day. Must match slotLockId() in firestore.rules.
String slotLockId(String studPigId, String date) => '${studPigId}_$date';

/// The /time_locks document id for a breeder's hourly slot — the breeder
/// can only be at one farm at a time, so each time is booked once across
/// all their pigs. "09:00 AM" is stored as "0900AM". Must match
/// timeLockId() in firestore.rules.
String timeLockId(String breederId, String date, String time) =>
    '${breederId}_${date}_${time.replaceAll(RegExp('[: ]'), '')}';

/// Bookings in these statuses no longer hold their day or time.
const _slotFreeingStatuses = ['cancelled', 'rejected'];

/// Thrown when the stud pig is already booked on the chosen day.
class SlotTakenException extends AppException {
  const SlotTakenException()
    : super(
        'Sorry, someone just booked this stud pig for that day. Please pick '
        'another date.',
      );
}

/// Thrown when another farmer already booked the breeder at the chosen time.
class TimeTakenException extends AppException {
  const TimeTakenException()
    : super(
        'Sorry, another farmer just booked this breeder at that time. Please '
        'pick a different time.',
      );
}

/// Why a booking can't be made; see
/// [BreedingRequestRepository.checkBookingConflict].
enum BookingConflict { pigBookedThatDay, timeTaken }

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

  /// Creates the booking, its conflict-check mirror and its two locks in
  /// one atomic write. The locks are what make double booking impossible:
  /// if another farmer claimed the same pig and day, or the same breeder
  /// and time, first — even a split second earlier — the whole write is
  /// rejected and nothing is saved.
  Future<void> sendRequest(BreedingRequestModel request) async {
    final bookingRef = _firestore.collection('bookings').doc();
    final lockRef = _firestore
        .collection('slot_locks')
        .doc(slotLockId(request.studPigId, request.bookingDate));
    final timeLockRef = _firestore
        .collection('time_locks')
        .doc(
          timeLockId(
            request.breederId,
            request.bookingDate,
            request.bookingTime,
          ),
        );

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
      ..set(lockRef, {'bookingId': bookingRef.id})
      ..set(timeLockRef, {'bookingId': bookingRef.id});

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // A taken slot is rejected as permission-denied; confirm that's the
      // reason before saying so. A lock outlives a cancelled booking, so
      // check for an active booking rather than just the lock.
      if (e.code == 'permission-denied') {
        final conflict = await checkBookingConflict(
          studPigId: request.studPigId,
          breederId: request.breederId,
          date: request.bookingDate,
          time: request.bookingTime,
        );
        if (conflict == BookingConflict.pigBookedThatDay) {
          throw const SlotTakenException();
        }
        if (conflict == BookingConflict.timeTaken) {
          throw const TimeTakenException();
        }
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

  /// Moves [booking] to [date] at [time]. It goes back to pending so the
  /// breeder confirms the new time, and — like [sendRequest] — claims the new
  /// day's and time's locks in the same atomic write, so it can't land on a
  /// taken slot. The old slot is freed for other farmers straight away.
  Future<void> rescheduleRequest(
    BreedingRequestModel booking, {
    required String date,
    required String time,
  }) async {
    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final batch = _firestore.batch()
      ..update(bookingRef, {
        'bookingDate': date,
        'bookingTime': time,
        'status': 'pending',
      })
      ..set(
        _firestore.collection('booking_slots').doc(booking.id),
        {
          'breederId': booking.breederId,
          'studPigId': booking.studPigId,
          'bookingDate': date,
          'bookingTime': time,
          'status': 'pending',
        },
        SetOptions(merge: true),
      )
      ..set(
        _firestore
            .collection('slot_locks')
            .doc(slotLockId(booking.studPigId, date)),
        {'bookingId': booking.id},
      )
      ..set(
        _firestore
            .collection('time_locks')
            .doc(timeLockId(booking.breederId, date, time)),
        {'bookingId': booking.id},
      );

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final conflict = await checkBookingConflict(
          studPigId: booking.studPigId,
          breederId: booking.breederId,
          date: date,
          time: time,
          exceptBookingId: booking.id,
        );
        if (conflict == BookingConflict.pigBookedThatDay) {
          throw const SlotTakenException();
        }
        if (conflict == BookingConflict.timeTaken) {
          throw const TimeTakenException();
        }
      }
      rethrow;
    }

    try {
      await _firestore
          .collection('notifications')
          .add(
            NotificationModel(
              id: '',
              userId: booking.breederId,
              title: 'Booking Rescheduled',
              body:
                  '${booking.farmerName} moved ${booking.studPigName} to '
                  '${formatBookingSchedule(date, time)}. Please accept the '
                  'new time.',
              type: 'booking',
              referenceId: booking.id,
              isRead: false,
              createdAt: DateTime.now(),
            ).toJson(),
          );
    } catch (e) {
      debugPrint('Failed to create reschedule notification: $e');
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
      ..set(
        _firestore.collection('booking_slots').doc(requestId),
        {
          'breederId': booking['breederId'],
          'studPigId': booking['studPigId'],
          'bookingDate': booking['bookingDate'],
          'bookingTime': booking['bookingTime'],
          'status': status,
        },
        SetOptions(merge: true),
      );
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

  /// Checks whether the booking can be made: a stud pig breeds at most
  /// once a day, and a breeder can only be at one farm per hourly slot, so
  /// [time] must be free across all of the breeder's pigs. Every status
  /// except cancelled/rejected holds its day and time, including
  /// done_breeding. Returns null when it's free.
  ///
  /// This gives the farmer a friendly answer up front; the locks in
  /// [sendRequest] are what actually guarantee no double booking. It reads
  /// from the server (never the offline cache, which could be stale), so
  /// offline it fails instead of queueing a booking that may be rejected.
  Future<BookingConflict?> checkBookingConflict({
    required String studPigId,
    required String breederId,
    required String date,
    required String time,
    // A booking being rescheduled doesn't conflict with itself.
    String? exceptBookingId,
  }) async {
    final query = await _firestore
        .collection('booking_slots')
        .where('breederId', isEqualTo: breederId)
        .where('bookingDate', isEqualTo: date)
        .get(const GetOptions(source: Source.server));

    final slot = bookingSlotOf(time);
    BookingConflict? conflict;
    for (final doc in query.docs) {
      final data = doc.data();
      if (doc.id == exceptBookingId) continue;
      if (_slotFreeingStatuses.contains(data['status'] ?? '')) continue;
      if (data['studPigId'] == studPigId) {
        return BookingConflict.pigBookedThatDay;
      }
      if (bookingSlotOf(data['bookingTime'] as String? ?? '') == slot) {
        conflict = BookingConflict.timeTaken;
      }
    }
    return conflict;
  }

  /// Live set of the hourly slots taken at [breederId]'s farm on [date],
  /// across all their pigs. Only for display; booking re-checks on the
  /// server.
  Stream<Set<String>> watchTakenTimes(
    String breederId,
    String date, {
    String? exceptBookingId,
  }) {
    return _firestore
        .collection('booking_slots')
        .where('breederId', isEqualTo: breederId)
        .where('bookingDate', isEqualTo: date)
        .snapshots()
        .map(
          (snapshot) => {
            for (final doc in snapshot.docs)
              if (doc.id != exceptBookingId &&
                  !_slotFreeingStatuses.contains(doc.data()['status'] ?? ''))
                ?bookingSlotOf(doc.data()['bookingTime'] as String? ?? ''),
          },
        );
  }

  /// How many of the stud pig's bookings are still under way (not yet
  /// completed, rejected or cancelled) — a pig with any can't be deleted,
  /// or those farmers would be left with a booking for a pig that's gone.
  Future<int> countActiveBookingsForPig(String studPigId) async {
    final query = await _firestore
        .collection('booking_slots')
        .where('studPigId', isEqualTo: studPigId)
        .get(const GetOptions(source: Source.server));
    return query.docs
        .where(
          (doc) =>
              !terminalBookingStatuses.contains(doc.data()['status'] ?? ''),
        )
        .length;
  }

  /// The dates (yyyy-MM-dd) the stud pig is already booked on, so the date
  /// picker can grey them out. Read from the server for the same reason as
  /// [checkBookingConflict].
  Future<Set<String>> getBookedDatesForPig(
    String studPigId, {
    String? exceptBookingId,
  }) async {
    final query = await _firestore
        .collection('booking_slots')
        .where('studPigId', isEqualTo: studPigId)
        .get(const GetOptions(source: Source.server));

    return {
      for (final doc in query.docs)
        if (doc.id != exceptBookingId &&
            !_slotFreeingStatuses.contains(doc.data()['status'] ?? ''))
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
