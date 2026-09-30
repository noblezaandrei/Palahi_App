import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/breeder/models/breeding_request_model.dart';
import '../../features/communication/models/notification_model.dart';
import '../../features/tracker/models/breeding_record.dart';
import '../l10n/app_strings.dart';
import '../routes/app_router.dart';
import '../utils/date_utils.dart';
import 'push_notification_service.dart';

/// A reminder to show on the phone at [at] (Philippine time).
class PlannedReminder {
  final String key;
  final DateTime at;
  final String title;
  final String body;

  /// The screen tapping it opens.
  final String route;

  const PlannedReminder({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    required this.route,
  });

  /// A stable notification id for this reminder.
  int get id => key.hashCode & 0x7fffffff;
}

/// The reminders [uid]'s phone should show, from their [bookings] (as
/// farmer or breeder) and the farmer's breeding [records]. Only ones still
/// ahead of [now]. The same timings the server reminders use
/// (functions/lib.js): 6 PM the evening before a booking, and 7 AM on the
/// Breeding Tracker's heat check and farrowing days.
List<PlannedReminder> planReminders({
  required String uid,
  required Iterable<BreedingRequestModel> bookings,
  required Map<String, BreedingRecord> records,
  required DateTime now,
}) {
  final plan = <PlannedReminder>[];
  for (final b in bookings) {
    final day = DateTime.tryParse(b.bookingDate);
    if (day == null) continue;
    DateTime at(int daysAfter, int hour) =>
        DateTime(day.year, day.month, day.day + daysAfter, hour);
    final time = displayBookingTime(b.bookingTime);

    // The evening before the booking.
    if (b.status == 'accepted') {
      final isFarmer = b.farmerId == uid;
      plan.add(
        PlannedReminder(
          key: 'booking_${b.id}',
          at: at(-1, 18),
          title: tr('Booking tomorrow'),
          body: isFarmer
              ? tr('{pig} from {breeder} is booked for tomorrow at {time}.', {
                  'pig': b.studPigName,
                  'breeder': b.breederName,
                  'time': time,
                })
              : tr("You're bringing {pig} to {farmer} tomorrow at {time}.", {
                  'pig': b.studPigName,
                  'farmer': b.farmerName,
                  'time': time,
                }),
          route: '/breeding-requests',
        ),
      );
    } else if (b.status == 'pending' && b.breederId == uid) {
      plan.add(
        PlannedReminder(
          key: 'pending_${b.id}',
          at: at(-1, 18),
          title: tr('Request waiting for you'),
          body: tr(
            '{farmer} wants {pig} tomorrow at {time}. Accept or reject it so they can plan.',
            {'farmer': b.farmerName, 'pig': b.studPigName, 'time': time},
          ),
          route: '/breeding-requests',
        ),
      );
    }

    // The farmer's Breeding Tracker, once breeding happened.
    final bred = b.status == 'done_breeding' || b.status == 'completed';
    if (!bred || b.farmerId != uid) continue;
    final outcome = records[b.id]?.outcome ?? BreedingOutcome.waiting;
    final due = formatShortDate(at(gestationDays, 0));
    if (outcome == BreedingOutcome.waiting) {
      plan.add(
        PlannedReminder(
          key: 'heat_${b.id}',
          at: at(heatCheckStartDay, 7),
          title: tr('Time for the heat check'),
          body: tr(
            'After breeding with {pig}, your sow may come back into heat from today until {date}. Check her daily and record it in the Breeding Tracker.',
            {
              'pig': b.studPigName,
              'date': formatShortDate(at(heatCheckEndDay, 0)),
            },
          ),
          route: '/breeding-tracker',
        ),
      );
    }
    if (outcome == BreedingOutcome.waiting ||
        outcome == BreedingOutcome.pregnant) {
      plan
        ..add(
          PlannedReminder(
            key: 'farrow3_${b.id}',
            at: at(gestationDays - 3, 7),
            title: tr('Farrowing in 3 days'),
            body: tr(
              'After breeding with {pig}, your sow is due to farrow around {date}. Get a clean, dry, warm farrowing pen ready.',
              {'pig': b.studPigName, 'date': due},
            ),
            route: '/breeding-tracker',
          ),
        )
        ..add(
          PlannedReminder(
            key: 'farrow_${b.id}',
            at: at(gestationDays, 7),
            title: tr('Farrowing due today'),
            body: tr(
              'After breeding with {pig}, your sow is due to farrow today. Keep an eye on her, and record the litter in the Breeding Tracker.',
              {'pig': b.studPigName},
            ),
            route: '/breeding-tracker',
          ),
        );
    }
  }
  return [
    for (final r in plan)
      if (r.at.isAfter(now)) r,
  ];
}

/// Notifications shown by the phone itself — free, no server needed.
///
/// Reminders are scheduled ahead of time, so they go off even when the app
/// is closed. Instant alerts (a booking accepted, a new message) are shown
/// while the app is open or still running in the background; reaching a
/// fully closed app needs the server push (see [PushNotifications]).
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String _lastPlan = '';

  static const _reminders = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Booking, heat check and farrowing reminders',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF2E7D32),
  );
  static const _alerts = AndroidNotificationDetails(
    'updates',
    'Bookings and messages',
    channelDescription: 'New bookings, booking updates and messages',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF2E7D32),
  );

  /// Sets up the plugin, asks for permission (Android 13+) and opens the
  /// screen of a reminder that launched the app. Safe to call repeatedly.
  static Future<void> start() async {
    if (kIsWeb) return;
    try {
      if (!_ready) {
        tzdata.initializeTimeZones();
        // PALAHI's users are in the Philippines, like the server reminders.
        tz.setLocalLocation(tz.getLocation('Asia/Manila'));
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_palahi'),
          ),
          onDidReceiveNotificationResponse: (response) =>
              _open(response.payload),
        );
        _ready = true;
      }
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _open(launch!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Could not set up local notifications: $e');
    }
  }

  /// Replaces this phone's scheduled reminders with [plan]. Does nothing
  /// when the plan hasn't changed.
  static Future<void> syncReminders(List<PlannedReminder> plan) async {
    if (!_ready) return;
    final signature = [
      for (final r in plan) '${r.key}@${r.at.toIso8601String()}',
    ].join('|');
    if (signature == _lastPlan) return;
    _lastPlan = signature;
    try {
      for (final pending in await _plugin.pendingNotificationRequests()) {
        await _plugin.cancel(id: pending.id);
      }
      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime(
            tz.local,
            r.at.year,
            r.at.month,
            r.at.day,
            r.at.hour,
          ),
          notificationDetails: const NotificationDetails(android: _reminders),
          // Inexact: no special alarm permission needed; Android may shift
          // it by a few minutes to save battery.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.route,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  /// Clears this phone's reminders, e.g. on sign-out.
  static Future<void> clearReminders() async {
    _lastPlan = '';
    if (!_ready) return;
    try {
      for (final pending in await _plugin.pendingNotificationRequests()) {
        await _plugin.cancel(id: pending.id);
      }
    } catch (e) {
      debugPrint('Could not clear reminders: $e');
    }
  }

  /// Shows a new in-app notification as a phone notification, when the app
  /// is in the background.
  static Future<void> showNow({
    required String id,
    required String title,
    required String body,
    required String route,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _alerts),
        payload: route,
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  static void _open(String? route) {
    if (route == null || route.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppRouter.router.push(route),
    );
  }
}

/// Shows each new in-app notification as it arrives: as a banner while the
/// app is on screen, or as a phone notification while it's in the
/// background. Notifications that were already there when the app opened
/// aren't shown again.
class InstantAlerts {
  final Set<String> _seen = {};
  bool _primed = false;

  void onNotifications(List<NotificationModel> list) {
    // With server push deployed, the phone already gets these as pushes.
    if (serverPushEnabled) return;
    if (!_primed) {
      _seen.addAll(list.map((n) => n.id));
      _primed = true;
      return;
    }
    for (final n in list) {
      if (!_seen.add(n.id) || n.isRead) continue;
      final route = routeForPush({'type': n.type}, null);
      final foreground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (foreground) {
        PushNotifications.showBanner(
          title: n.title,
          body: n.body,
          type: n.type,
          referenceId: n.referenceId,
          route: route,
        );
      } else {
        LocalNotifications.showNow(
          id: n.id,
          title: n.title,
          body: n.body,
          route: route,
        );
      }
    }
  }
}
