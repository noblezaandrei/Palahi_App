import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/tracker/models/breeding_record.dart';
import 'package:palahi/features/tracker/repositories/breeding_record_repository.dart';
import 'package:palahi/features/tracker/views/breeding_tracker_screen.dart';

class _FakeRecords implements BreedingRecordRepository {
  final saved = <(BreedingOutcome, int?)>[];

  @override
  Future<void> saveOutcome(
    BreedingRequestModel booking,
    BreedingOutcome outcome, {
    int? litterSize,
    String? farrowedOn,
  }) async => saved.add((outcome, litterSize));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final bredOn = DateTime.now().subtract(const Duration(days: 60));
  final booking = BreedingRequestModel(
    id: 'b1',
    farmerId: 'F',
    farmerName: 'Juan',
    farmerImageUrl: '',
    breederId: 'B',
    breederName: 'Green Valley',
    breederImageUrl: '',
    studPigId: 'p1',
    studPigName: 'Duroc King',
    studPigImageUrl: '',
    status: 'completed',
    breedingType: 'Manual Breeding',
    bookingDate:
        '${bredOn.year}-${bredOn.month.toString().padLeft(2, '0')}-${bredOn.day.toString().padLeft(2, '0')}',
    bookingTime: '09:00 AM',
    notes: '',
    createdAt: bredOn,
  );
  const record = BreedingRecord(
    bookingId: 'b1',
    farmerId: 'F',
    breederId: 'B',
    studPigId: 'p1',
    outcome: BreedingOutcome.pregnant,
  );

  Future<_FakeRecords> pumpCard(WidgetTester tester) async {
    final repo = _FakeRecords();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [breedingRecordRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BreedingTrackerCard(
                tracked: (booking: booking, record: record),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  // Cancelling this dialog used to dispose its text field's controller while
  // the dialog was still closing — a red screen on phones.
  testWidgets('cancelling "She farrowed!" closes cleanly', (tester) async {
    final repo = await pumpCard(tester);
    await tester.tap(find.text('She farrowed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('She farrowed!'), findsNothing);
    expect(repo.saved, isEmpty);
  });

  testWidgets('saving the litter size records the farrowing', (tester) async {
    final repo = await pumpCard(tester);
    await tester.tap(find.text('She farrowed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '11');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.saved, [(BreedingOutcome.farrowed, 11)]);
  });
}
