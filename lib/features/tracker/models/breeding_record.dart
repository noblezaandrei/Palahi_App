import 'package:cloud_firestore/cloud_firestore.dart';

/// What happened after a breeding, as the farmer reports it.
enum BreedingOutcome {
  /// Not reported yet.
  waiting,

  /// Didn't come back into heat — she conceived.
  pregnant,

  /// Came back into heat — she didn't conceive.
  notPregnant,

  /// Gave birth.
  farrowed;

  String get key => switch (this) {
    waiting => 'waiting',
    pregnant => 'pregnant',
    notPregnant => 'not_pregnant',
    farrowed => 'farrowed',
  };

  static BreedingOutcome fromKey(String? key) => switch (key) {
    'pregnant' => pregnant,
    'not_pregnant' => notPregnant,
    'farrowed' => farrowed,
    _ => waiting,
  };
}

/// The farmer's follow-up on one breeding (one booking), stored at
/// /breeding_records/{bookingId}. Also what gives each boar a conception
/// rate for its breeder.
class BreedingRecord {
  final String bookingId;
  final String farmerId;
  final String breederId;
  final String studPigId;
  final BreedingOutcome outcome;
  final int? litterSize;
  final String? farrowedOn; // yyyy-MM-dd

  const BreedingRecord({
    required this.bookingId,
    required this.farmerId,
    required this.breederId,
    required this.studPigId,
    this.outcome = BreedingOutcome.waiting,
    this.litterSize,
    this.farrowedOn,
  });

  factory BreedingRecord.fromJson(Map<String, dynamic> json, String id) {
    return BreedingRecord(
      bookingId: id,
      farmerId: json['farmerId'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      studPigId: json['studPigId'] as String? ?? '',
      outcome: BreedingOutcome.fromKey(json['outcome'] as String?),
      litterSize: (json['litterSize'] as num?)?.toInt(),
      farrowedOn: json['farrowedOn'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'farmerId': farmerId,
    'breederId': breederId,
    'studPigId': studPigId,
    'outcome': outcome.key,
    'litterSize': ?litterSize,
    'farrowedOn': ?farrowedOn,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Pig reproduction timings, counted from the breeding day.
///
/// A sow that didn't conceive comes back into heat about 21 days later, so
/// days 18–24 are when to watch for it. Gestation is about 114 days
/// ("3 months, 3 weeks, 3 days"). The Cloud Function reminders use the same
/// numbers (functions/lib.js).
const heatCheckStartDay = 18;
const heatCheckEndDay = 24;
const gestationDays = 114;

/// Where a breeding stands on a given day.
enum TrackerStage {
  /// Before the heat check window.
  waitingForHeatCheck,

  /// Days 18–24: watch whether she comes back into heat.
  heatCheckNow,

  /// Past the window and still not reported.
  heatCheckOverdue,

  /// Confirmed pregnant; counting down to farrowing.
  pregnant,

  /// Pregnant and within 3 days of (or past) the due date.
  farrowingSoon,

  /// She came back into heat — time to book again.
  notPregnant,

  /// Gave birth. Done.
  farrowed,
}

/// The dates and stage for a sow bred on [bredOn], as of [today].
class BreedingTimeline {
  final DateTime bredOn;
  final BreedingOutcome outcome;
  final DateTime today;

  BreedingTimeline({
    required DateTime bredOn,
    required this.outcome,
    required DateTime today,
  }) : bredOn = DateTime(bredOn.year, bredOn.month, bredOn.day),
       today = DateTime(today.year, today.month, today.day);

  DateTime _plus(int days) =>
      DateTime(bredOn.year, bredOn.month, bredOn.day + days);

  DateTime get heatCheckFrom => _plus(heatCheckStartDay);
  DateTime get heatCheckTo => _plus(heatCheckEndDay);
  DateTime get farrowingDue => _plus(gestationDays);

  /// Whole days since breeding (0 on the day itself).
  int get dayOfPregnancy => today.difference(bredOn).inDays;

  /// Days until the due date (negative once it's passed).
  int get daysToFarrowing => farrowingDue.difference(today).inDays;

  /// 0–1 through the ~114-day pregnancy, for a progress bar.
  double get progress => (dayOfPregnancy / gestationDays).clamp(0.0, 1.0);

  TrackerStage get stage {
    switch (outcome) {
      case BreedingOutcome.farrowed:
        return TrackerStage.farrowed;
      case BreedingOutcome.notPregnant:
        return TrackerStage.notPregnant;
      case BreedingOutcome.pregnant:
        return daysToFarrowing <= 3
            ? TrackerStage.farrowingSoon
            : TrackerStage.pregnant;
      case BreedingOutcome.waiting:
        if (today.isBefore(heatCheckFrom)) {
          return TrackerStage.waitingForHeatCheck;
        }
        if (!today.isAfter(heatCheckTo)) return TrackerStage.heatCheckNow;
        return TrackerStage.heatCheckOverdue;
    }
  }
}
