import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/auth_repository.dart';
import '../../breeder/models/breeding_request_model.dart';
import '../../breeder/repositories/breeding_request_repository.dart';
import '../models/breeding_record.dart';

final breedingRecordRepositoryProvider = Provider<BreedingRecordRepository>(
  (ref) => BreedingRecordRepository(FirebaseFirestore.instance),
);

/// The farmer's breeding records, keyed by booking id.
final farmerBreedingRecordsProvider =
    StreamProvider.family<Map<String, BreedingRecord>, String>((ref, farmerId) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRecordRepositoryProvider)
          .watchRecords('farmerId', farmerId);
    });

/// The records farmers reported on this breeder's boars, keyed by booking
/// id — for each boar's conception rate.
final breederBreedingRecordsProvider =
    StreamProvider.family<Map<String, BreedingRecord>, String>((
      ref,
      breederId,
    ) {
      ref.watch(authStateProvider);
      return ref
          .watch(breedingRecordRepositoryProvider)
          .watchRecords('breederId', breederId);
    });

/// One sow's breeding to follow up: the booking plus whatever the farmer
/// has reported so far.
typedef TrackedBreeding = ({
  BreedingRequestModel booking,
  BreedingRecord? record,
});

/// The farmer's breedings to follow up — every booking where breeding
/// happened (done_breeding or completed) — newest first.
final farmerTrackedBreedingsProvider =
    Provider.family<AsyncValue<List<TrackedBreeding>>, String>((ref, farmerId) {
      final bookings = ref.watch(farmerRequestsProvider(farmerId));
      final records = ref.watch(farmerBreedingRecordsProvider(farmerId));
      if (bookings.hasError) {
        return AsyncValue.error(bookings.error!, bookings.stackTrace!);
      }
      if (!bookings.hasValue || !records.hasValue) {
        return const AsyncValue.loading();
      }
      final byId = records.value!;
      final list = [
        for (final b in bookings.value!)
          if (b.status == 'done_breeding' || b.status == 'completed')
            (booking: b, record: byId[b.id]),
      ]..sort((a, b) => b.booking.bookingDate.compareTo(a.booking.bookingDate));
      return AsyncValue.data(list);
    });

/// A boar's conception rate from farmers' reports: how many of the
/// breedings with a known result took.
({int conceived, int reported}) conceptionRate(
  Iterable<BreedingRecord> records,
  String studPigId,
) {
  var conceived = 0;
  var reported = 0;
  for (final r in records) {
    if (r.studPigId != studPigId) continue;
    switch (r.outcome) {
      case BreedingOutcome.pregnant:
      case BreedingOutcome.farrowed:
        conceived++;
        reported++;
      case BreedingOutcome.notPregnant:
        reported++;
      case BreedingOutcome.waiting:
        break;
    }
  }
  return (conceived: conceived, reported: reported);
}

class BreedingRecordRepository {
  final FirebaseFirestore _firestore;

  BreedingRecordRepository(this._firestore);

  Stream<Map<String, BreedingRecord>> watchRecords(
    String field,
    String userId,
  ) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('breeding_records')
              .where(field, isEqualTo: userId)
              .snapshots()) {
        yield {
          for (final doc in snapshot.docs)
            doc.id: BreedingRecord.fromJson(doc.data(), doc.id),
        };
      }
    } catch (error) {
      debugPrint('Failed to load breeding records: $error');
      yield const {};
    }
  }

  /// Saves what happened after [booking]'s breeding.
  Future<void> saveOutcome(
    BreedingRequestModel booking,
    BreedingOutcome outcome, {
    int? litterSize,
    String? farrowedOn,
  }) {
    return _firestore
        .collection('breeding_records')
        .doc(booking.id)
        .set(
          BreedingRecord(
            bookingId: booking.id,
            farmerId: booking.farmerId,
            breederId: booking.breederId,
            studPigId: booking.studPigId,
            outcome: outcome,
            litterSize: litterSize,
            farrowedOn: farrowedOn,
          ).toJson(),
        );
  }
}
