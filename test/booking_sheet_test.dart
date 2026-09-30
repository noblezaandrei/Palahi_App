import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/utils/date_utils.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/breeder/models/stud_pig_model.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/views/widgets/booking_sheet.dart';

class _FakeRepository implements BreedingRequestRepository {
  final Set<String> pigBookedDates;

  _FakeRepository(this.pigBookedDates);

  @override
  Future<Set<String>> getBookedDatesForPig(
    String studPigId, {
    String? exceptBookingId,
  }) async => pigBookedDates;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final dayAfter = today.add(const Duration(days: 2));

  final breeder = BreederModel(
    id: 'breeder_1',
    userId: 'breeder_1',
    farmName: 'Green Valley',
    location: 'Legazpi',
    latitude: 0,
    longitude: 0,
    rating: 5,
    reviewCount: 0,
    imageUrl: '',
    about: '',
    services: const [],
    availableDates: [dateKey(tomorrow), dateKey(dayAfter)],
  );
  final pig = StudPigModel(
    id: 'pig_1',
    breederId: 'breeder_1',
    name: 'Duroc King',
    breed: 'Duroc',
    ageMonths: 18,
    weight: 210,
    price: 1500,
    imageUrl: '',
    isAvailable: true,
    description: '',
    serviceType: 'Natural Breeding',
  );

  Future<StreamController<Set<String>>> pumpSheet(WidgetTester tester) async {
    final takenTimes = StreamController<Set<String>>.broadcast();
    addTearDown(takenTimes.close);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The pig is already booked the day after tomorrow.
          breedingRequestRepositoryProvider.overrideWithValue(
            _FakeRepository({dateKey(dayAfter)}),
          ),
          breederTakenTimesProvider.overrideWith(
            (ref, day) => takenTimes.stream,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BookingSheet(breeder: breeder, pig: pig, farmerName: 'Juan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return takenTimes;
  }

  Finder bookButton() => find.ancestor(
    of: find.text('Book'),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  bool bookEnabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(bookButton()).onPressed != null;

  Future<void> tapSlot(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('times are hidden until a date is picked', (tester) async {
    await pumpSheet(tester);

    expect(find.textContaining('Pick a date first'), findsOneWidget);
    expect(find.text('8:00 AM'), findsNothing);
    expect(bookEnabled(tester), isFalse);
  });

  testWidgets("a day the pig is already booked can't be picked", (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text(weekdayShort(dayAfter).toUpperCase()));
    await tester.pump();

    expect(find.textContaining('Pick a date first'), findsOneWidget);
  });

  testWidgets("times other farmers booked are shown and can't be picked", (
    tester,
  ) async {
    final takenTimes = await pumpSheet(tester);

    await tester.tap(find.text(weekdayShort(tomorrow).toUpperCase()));
    await tester.pump();
    takenTimes.add({'09:00 AM', '01:00 PM'});
    await tester.pump();

    expect(find.text('9:00 AM'), findsOneWidget);
    // The legend, the pig's booked day in the date strip, and the two
    // booked slots.
    expect(find.text('Booked'), findsNWidgets(4));

    await tapSlot(tester, '9:00 AM');
    expect(find.text('No time chosen yet'), findsOneWidget);
    expect(bookEnabled(tester), isFalse);

    await tapSlot(tester, '10:00 AM');
    expect(find.textContaining('· 10:00 AM'), findsOneWidget);
    expect(bookEnabled(tester), isTrue);
  });

  testWidgets('a time booked by someone else while choosing is dropped', (
    tester,
  ) async {
    final takenTimes = await pumpSheet(tester);

    await tester.tap(find.text(weekdayShort(tomorrow).toUpperCase()));
    await tester.pump();
    takenTimes.add({});
    await tester.pump();
    await tapSlot(tester, '10:00 AM');
    expect(bookEnabled(tester), isTrue);

    // Another farmer books 10:00 AM with this breeder.
    takenTimes.add({'10:00 AM'});
    await tester.pump();
    await tester.pump();

    expect(find.text('No time chosen yet'), findsOneWidget);
    expect(find.textContaining('was just booked by another farmer'), findsOne);
    expect(bookEnabled(tester), isFalse);
  });
}
