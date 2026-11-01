import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/utils/date_utils.dart';
import 'package:palahi/features/breeder/models/stud_pig_model.dart';
import 'package:palahi/features/breeder/views/widgets/pig_availability.dart';

void main() {
  group('pigUnavailableReason', () {
    final pig = StudPigModel.fromJson({'name': 'Boar'}, 'p1');
    final today = DateTime(2026, 10, 6);
    final todayKey = dateKey(today);
    final tomorrowKey = dateKey(DateTime(2026, 10, 7));

    test('today still counts while its last slot is ahead', () {
      expect(
        pigUnavailableReason(
          pig,
          [todayKey],
          {},
          now: DateTime(2026, 10, 6, 9),
        ),
        isNull,
      );
    });

    test('today no longer counts once its last slot has started', () {
      // Matches the booking sheet, which leaves today out after 5 PM.
      expect(
        pigUnavailableReason(
          pig,
          [todayKey],
          {},
          now: DateTime(2026, 10, 6, 17, 30),
        ),
        'No open dates',
      );
      expect(
        pigUnavailableReason(
          pig,
          [todayKey, tomorrowKey],
          {},
          now: DateTime(2026, 10, 6, 17, 30),
        ),
        isNull,
      );
    });

    test('fully booked on every remaining day', () {
      expect(
        pigUnavailableReason(
          pig,
          [todayKey, tomorrowKey],
          {tomorrowKey},
          now: DateTime(2026, 10, 6, 18),
        ),
        'Fully booked',
      );
    });
  });

  test('one unambiguous long date format', () {
    expect(formatLongDate(DateTime(2026, 10, 6)), 'Tue, Oct 6, 2026');
    expect(formatStoredDate('2026-10-06'), 'Tue, Oct 6, 2026');
    expect(formatStoredDate('not a date'), 'not a date');
  });
}
