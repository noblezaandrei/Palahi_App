import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/tracker/models/breeding_record.dart';
import 'package:palahi/features/tracker/repositories/breeding_record_repository.dart';

void main() {
  final bred = DateTime(2026, 10, 1);

  BreedingTimeline on(
    DateTime today, [
    BreedingOutcome o = BreedingOutcome.waiting,
  ]) => BreedingTimeline(bredOn: bred, outcome: o, today: today);

  test('heat check and farrowing dates count from the breeding day', () {
    final t = on(DateTime(2026, 10, 5));
    expect(t.heatCheckFrom, DateTime(2026, 10, 19));
    expect(t.heatCheckTo, DateTime(2026, 10, 25));
    expect(t.farrowingDue, DateTime(2027, 1, 23));
  });

  test('the stage follows the calendar until the farmer reports', () {
    expect(on(DateTime(2026, 10, 18)).stage, TrackerStage.waitingForHeatCheck);
    expect(on(DateTime(2026, 10, 19)).stage, TrackerStage.heatCheckNow);
    expect(on(DateTime(2026, 10, 25)).stage, TrackerStage.heatCheckNow);
    expect(on(DateTime(2026, 10, 26)).stage, TrackerStage.heatCheckOverdue);
  });

  test('a pregnant sow counts down to farrowing', () {
    final t = on(DateTime(2026, 11, 1), BreedingOutcome.pregnant);
    expect(t.stage, TrackerStage.pregnant);
    expect(t.dayOfPregnancy, 31);
    expect(t.daysToFarrowing, 83);
    expect(
      on(DateTime(2027, 1, 20), BreedingOutcome.pregnant).stage,
      TrackerStage.farrowingSoon,
    );
  });

  test('reported outcomes win over the calendar', () {
    final day20 = DateTime(2026, 10, 21);
    expect(
      on(day20, BreedingOutcome.notPregnant).stage,
      TrackerStage.notPregnant,
    );
    expect(on(day20, BreedingOutcome.farrowed).stage, TrackerStage.farrowed);
  });

  test("a boar's conception rate counts only reported results", () {
    BreedingRecord r(String pig, BreedingOutcome o) => BreedingRecord(
      bookingId: 'x',
      farmerId: 'f',
      breederId: 'b',
      studPigId: pig,
      outcome: o,
    );
    final records = [
      r('p1', BreedingOutcome.pregnant),
      r('p1', BreedingOutcome.farrowed),
      r('p1', BreedingOutcome.notPregnant),
      r('p1', BreedingOutcome.waiting),
      r('p2', BreedingOutcome.pregnant),
    ];
    expect(conceptionRate(records, 'p1'), (conceived: 2, reported: 3));
    expect(conceptionRate(records, 'p3'), (conceived: 0, reported: 0));
  });
}
