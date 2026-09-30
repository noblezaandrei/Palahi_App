import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/services/local_notification_service.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/tracker/models/breeding_record.dart';

BreedingRequestModel booking(String id, String status, String date) =>
    BreedingRequestModel(
      id: id,
      farmerId: 'F',
      farmerName: 'Juan',
      farmerImageUrl: '',
      breederId: 'B',
      breederName: 'Green Valley Farm',
      breederImageUrl: '',
      studPigId: 'p1',
      studPigName: 'Duroc King',
      studPigImageUrl: '',
      status: status,
      breedingType: 'Manual Breeding',
      bookingDate: date,
      bookingTime: '09:00 AM',
      notes: '',
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 10, 1, 12);

  test('an accepted booking reminds both sides at 6 PM the day before', () {
    final b = booking('b1', 'accepted', '2026-10-05');
    final farmer = planReminders(
      uid: 'F',
      bookings: [b],
      records: {},
      now: now,
    );
    final breeder = planReminders(
      uid: 'B',
      bookings: [b],
      records: {},
      now: now,
    );

    expect(farmer.single.at, DateTime(2026, 10, 4, 18));
    expect(farmer.single.body, contains('Duroc King from Green Valley Farm'));
    expect(breeder.single.body, contains('bringing Duroc King to Juan'));
  });

  test('a pending request nudges only the breeder', () {
    final b = booking('b1', 'pending', '2026-10-05');
    expect(
      planReminders(uid: 'F', bookings: [b], records: {}, now: now),
      isEmpty,
    );
    expect(
      planReminders(
        uid: 'B',
        bookings: [b],
        records: {},
        now: now,
      ).single.title,
      'Request waiting for you',
    );
  });

  test(
    'a sow after breeding gets heat check and farrowing reminders at 7 AM',
    () {
      final b = booking('b1', 'completed', '2026-09-28');
      final plan = planReminders(
        uid: 'F',
        bookings: [b],
        records: {},
        now: now,
      );

      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 16, 7), // day 18
        DateTime(2027, 1, 17, 7), // 3 days before farrowing
        DateTime(2027, 1, 20, 7), // day 114
      ]);
      expect(plan.every((r) => r.route == '/breeding-tracker'), isTrue);
      // The breeder doesn't get the farmer's tracker reminders.
      expect(
        planReminders(uid: 'B', bookings: [b], records: {}, now: now),
        isEmpty,
      );
    },
  );

  test('reported outcomes and past dates drop reminders', () {
    final b = booking('b1', 'completed', '2026-09-28');
    BreedingRecord rec(BreedingOutcome o) => BreedingRecord(
      bookingId: 'b1',
      farmerId: 'F',
      breederId: 'B',
      studPigId: 'p1',
      outcome: o,
    );
    // Pregnant: no heat check, still the farrowing ones.
    expect(
      planReminders(
        uid: 'F',
        bookings: [b],
        records: {'b1': rec(BreedingOutcome.pregnant)},
        now: now,
      ).length,
      2,
    );
    for (final o in [BreedingOutcome.notPregnant, BreedingOutcome.farrowed]) {
      expect(
        planReminders(
          uid: 'F',
          bookings: [b],
          records: {'b1': rec(o)},
          now: now,
        ),
        isEmpty,
      );
    }
    // A booking whose reminder time already passed.
    final past = booking('b2', 'accepted', '2026-10-01');
    expect(
      planReminders(uid: 'F', bookings: [past], records: {}, now: now),
      isEmpty,
    );
  });

  test('each reminder keeps the same id between re-plans', () {
    final b = booking('b1', 'accepted', '2026-10-05');
    final a = planReminders(uid: 'F', bookings: [b], records: {}, now: now);
    final again = planReminders(uid: 'F', bookings: [b], records: {}, now: now);
    expect(a.single.id, again.single.id);
  });
}
