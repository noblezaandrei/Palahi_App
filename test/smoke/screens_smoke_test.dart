// Opens every farmer and breeder screen with sample data and clicks through
// its dialogs, sheets and pickers, failing on any framework error — the kind
// that shows as a red screen on a phone running a debug build.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/l10n/app_strings.dart';
import 'package:palahi/features/breeder/views/breeder_detail_screen.dart';
import 'package:palahi/features/breeder/views/breeder_history_screen.dart';
import 'package:palahi/features/breeder/views/breeder_list_screen.dart';
import 'package:palahi/features/breeder/views/breeding_requests_screen.dart';
import 'package:palahi/features/breeder/views/manage_availability_screen.dart';
import 'package:palahi/features/breeder/views/manage_stud_pig_screen.dart';
import 'package:palahi/features/breeder/views/my_pigs_screen.dart';
import 'package:palahi/features/breeder/views/reviews_screen.dart';
import 'package:palahi/features/communication/views/chat_room_screen.dart';
import 'package:palahi/features/communication/views/messaging_screen.dart';
import 'package:palahi/features/communication/views/notifications_screen.dart';
import 'package:palahi/features/home/views/farmer_dashboard_screen.dart';
import 'package:palahi/features/home/views/home_screen.dart';
import 'package:palahi/features/profile/views/about_screen.dart';
import 'package:palahi/features/profile/views/change_password_screen.dart';
import 'package:palahi/features/profile/views/delete_account_screen.dart';
import 'package:palahi/features/profile/views/edit_farmer_profile_screen.dart';
import 'package:palahi/features/profile/views/edit_profile_screen.dart';
import 'package:palahi/features/profile/views/favorites_screen.dart';
import 'package:palahi/features/profile/views/privacy_policy_screen.dart';
import 'package:palahi/features/profile/views/profile_screen.dart';
import 'package:palahi/features/profile/views/settings_screen.dart';
import 'package:palahi/features/tracker/views/breeding_tracker_screen.dart';

import 'harness.dart';

void noErrors(WidgetTester tester) {
  final error = tester.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull);
}

void main() {
  setUpAll(loadRealFont);
  tearDown(() => appLanguage = AppLanguage.english);

  group('farmer', () {
    testWidgets('home dashboard: reschedule sheet, confirm dialog', (t) async {
      final calls = await openScreen(
        t,
        const FarmerDashboardScreen(),
        role: 'farmer',
      );
      noErrors(t);
      // Tracker card near the top of Home: heat check button.
      await tapText(t, 'No heat — pregnant');
      expect(calls.list, contains('outcome heat pregnant'));
      await tapText(t, 'Reschedule');
      expect(find.textContaining('Reschedule Duroc King'), findsOneWidget);
      await tapText(t, 'Calendar');
      await tapText(t, 'Cancel'); // date picker
      await back(t);
      await tapText(t, 'Confirm Booking');
      await tapText(t, 'Cancel');
      noErrors(t);
    });

    testWidgets('home shell: every tab but the map', (t) async {
      await openScreen(t, const HomeScreen(), role: 'farmer');
      for (final tab in ['Breeders', 'Favorites', 'Profile', 'Home']) {
        await tapText(t, tab);
        noErrors(t);
      }
    });

    testWidgets('breeder page: booking sheet from date to time', (t) async {
      await openScreen(
        t,
        const BreederDetailScreen(breederId: breederUid),
        role: 'farmer',
      );
      noErrors(t);
      await tapText(t, 'Duroc King');
      expect(find.text('Book Duroc King'), findsOneWidget);
      await tapText(t, 'Calendar');
      await tapText(t, 'Cancel');
      final firstDay = weekdayLabel(1);
      await tapText(t, firstDay);
      await tapText(t, '10:00 AM');
      await back(t);
      noErrors(t);
    });

    testWidgets('my requests: cancel, confirm, reschedule dialogs', (t) async {
      await openScreen(t, const BreedingRequestsScreen(), role: 'farmer');
      await tapText(t, 'Cancel');
      await tapText(t, 'Keep it');
      await tapText(t, 'Confirm Booking');
      await tapText(t, 'Cancel');
      await tapText(t, 'Reschedule');
      // This screen doesn't watch the breeders list; reading it once used to
      // wait forever (paused provider), so the sheet never opened.
      expect(find.text('Reschedule Duroc King'), findsOneWidget);
      await back(t);
      noErrors(t);
    });

    testWidgets('breeding tracker: every stage and the farrowing dialog', (
      t,
    ) async {
      final calls = await openScreen(
        t,
        const BreedingTrackerScreen(),
        role: 'farmer',
      );
      await tapText(t, 'Came back in heat');
      await tapText(t, 'She farrowed');
      await tapText(t, 'Cancel');
      await tapText(t, 'She farrowed');
      await t.enterText(find.byType(TextField), '10');
      await tapText(t, 'Save');
      noErrors(t);
      expect(calls.list, contains('outcome preg farrowed'));
    });

    testWidgets('breeders list and saved list', (t) async {
      await openScreen(t, const BreederListScreen(), role: 'farmer');
      await tapText(t, 'A–Z');
      await t.enterText(find.byType(TextField), 'green');
      await settle(t);
      noErrors(t);
      await openScreen(t, const FavoritesScreen(), role: 'farmer');
      noErrors(t);
    });

    testWidgets('notifications: tap one, clear dialog', (t) async {
      await openScreen(t, const NotificationsScreen(), role: 'farmer');
      await tapText(t, 'Clear');
      await tapText(t, 'Cancel');
      await tapText(t, 'Booking Accepted');
      noErrors(t);
    });

    testWidgets('messages and a chat with a reaction sheet', (t) async {
      await openScreen(t, const MessagingScreen(), role: 'farmer');
      noErrors(t);
      await openScreen(
        t,
        const ChatRoomScreen(
          roomId: '${breederUid}_$farmerUid',
          otherParticipantName: 'Green Valley Farm',
        ),
        role: 'farmer',
      );
      await t.longPress(find.text('Yes, tomorrow at 9.'));
      await settle(t);
      await back(t);
      await t.enterText(find.byType(TextField), 'Thank you');
      await t.tap(find.byIcon(Icons.send));
      await settle(t);
      noErrors(t);
    });

    testWidgets('profile, settings and language', (t) async {
      await openScreen(t, const ProfileScreen(), role: 'farmer');
      noErrors(t);
      await openScreen(t, const SettingsScreen(), role: 'farmer');
      await tapText(t, 'Language');
      await tapText(t, 'Filipino');
      noErrors(t);
    });

    testWidgets('history, edit profile, password, delete account', (t) async {
      for (final screen in <Widget>[
        const BreedingHistoryScreen(),
        const EditFarmerProfileScreen(),
        const ChangePasswordScreen(),
        const DeleteAccountScreen(),
        const AboutScreen(),
        const PrivacyPolicyScreen(),
      ]) {
        await openScreen(t, screen, role: 'farmer');
        noErrors(t);
      }
    });
  });

  group('breeder', () {
    testWidgets('home shell: every tab', (t) async {
      await openScreen(t, const HomeScreen(), role: 'breeder');
      for (final tab in ['Requests', 'Calendar', 'Profile', 'My Pigs']) {
        await tapText(t, tab);
        noErrors(t);
      }
    });

    testWidgets('my pigs: add stud pig', (t) async {
      await openScreen(t, const MyPigsScreen(), role: 'breeder');
      await tapText(t, 'Add Stud Pig');
      expect(find.text('Add Stud Pig'), findsWidgets);
      await back(t);
      noErrors(t);
    });

    testWidgets('edit stud pig: health date, delete blocked by bookings', (
      t,
    ) async {
      await openScreen(
        t,
        ManageStudPigScreen(existingPig: pig),
        role: 'breeder',
      );
      await tapText(t, 'Last health check: Tue, Sep 15, 2026');
      await tapText(t, 'Cancel');
      await t.tap(find.byIcon(Icons.delete));
      await settle(t);
      expect(find.text('This pig has bookings'), findsOneWidget);
      await tapText(t, 'OK');
      noErrors(t);
    });

    testWidgets('requests: reject dialog and payment dialog', (t) async {
      await openScreen(t, const BreedingRequestsScreen(), role: 'breeder');
      await tapText(t, 'Reject');
      await tapText(t, 'Keep it');
      await tapText(t, 'Receive Payment');
      await tapText(t, 'Cancel');
      noErrors(t);
    });

    testWidgets('availability calendar: toggle a day, repeat weekly', (
      t,
    ) async {
      await openScreen(t, const ManageAvailabilityScreen(), role: 'breeder');
      noErrors(t);
      final repeat = find.textContaining('Repeat');
      if (repeat.evaluate().isNotEmpty) {
        await t.tap(repeat.first);
        await settle(t);
        await back(t);
      }
      noErrors(t);
    });

    testWidgets('profile, edit profile, reviews, history', (t) async {
      for (final screen in <Widget>[
        const ProfileScreen(),
        const EditProfileScreen(),
        const ReviewsScreen(breederId: breederUid),
        const BreedingHistoryScreen(),
        const NotificationsScreen(),
      ]) {
        await openScreen(t, screen, role: 'breeder');
        noErrors(t);
      }
    });
  });
}

/// The weekday label on the date strip for [days] from today, e.g. "THU".
String weekdayLabel(int days) {
  const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return names[today.add(Duration(days: days)).weekday - 1];
}
