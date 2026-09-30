import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/communication/models/notification_model.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/features/communication/views/notifications_screen.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthRepository {
  @override
  User? get currentUser => _FakeUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationModel _n(String id, {required bool read}) => NotificationModel(
  id: id,
  userId: 'u1',
  title: 'Booking Accepted',
  body: 'Green Valley Farm accepted your booking.',
  type: 'booking',
  referenceId: 'b1',
  isRead: read,
  createdAt: DateTime(2026, 9, 30, 15, 7),
);

void main() {
  // Unread rows are tinted; this used to wrap the ListTile in a coloured
  // box, which newer Flutter rejects — a red screen on real phones.
  testWidgets('notifications with unread ones open without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuth()),
          userNotificationsProvider.overrideWith(
            (ref, uid) =>
                Stream.value([_n('1', read: false), _n('2', read: true)]),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Booking Accepted'), findsNWidgets(2));
  });
}
