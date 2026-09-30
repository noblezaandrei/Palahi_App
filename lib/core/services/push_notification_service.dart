import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../routes/app_router.dart';

/// Whether the pushOnNotification Cloud Function is deployed (it needs the
/// paid Blaze plan). While false, the phone shows new notifications itself
/// ([InstantAlerts] in local_notification_service.dart) — only while the
/// app is running. Set to true after `firebase deploy --only functions`, so
/// the same notification isn't shown twice.
const serverPushEnabled = false;

/// Shows pushes that arrive while the app is open (Android only displays
/// them itself when the app is in the background).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Phone push notifications. The Cloud Function `pushOnNotification` sends
/// every in-app notification to the phones listed in the recipient's
/// `users/{uid}.fcmTokens`; this registers this phone there and opens the
/// right screen when a push is tapped.
class PushNotifications {
  PushNotifications._();

  static String? _uid;
  static StreamSubscription<String>? _tokenRefresh;
  static bool _listening = false;

  /// The chat room open on screen right now, if any — its message pushes
  /// aren't shown as a banner, since the messages appear right there.
  static String? openChatRoomId;

  /// Registers this phone for [uid]'s pushes. Safe to call repeatedly.
  static Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    try {
      final messaging = FirebaseMessaging.instance;
      // Android 13+ asks the user; older versions allow it by default.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notifications not allowed by the user.');
      }

      final token = await messaging.getToken();
      if (token != null) await _saveToken(uid, token);
      await _tokenRefresh?.cancel();
      _tokenRefresh = messaging.onTokenRefresh.listen(
        (token) => _saveToken(uid, token),
      );

      if (!_listening) {
        _listening = true;
        FirebaseMessaging.onMessage.listen(_showInApp);
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
        // Tapped while the app was fully closed.
        final initial = await messaging.getInitialMessage();
        if (initial != null) _open(initial);
      }
    } catch (e) {
      // Push is a bonus; the in-app notifications still work without it.
      debugPrint('Could not set up push notifications: $e');
    }
  }

  /// Stops sending pushes for the signed-in user to this phone. Call before
  /// signing out, while still allowed to edit the profile.
  static Future<void> stop() async {
    final uid = _uid;
    _uid = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      debugPrint('Could not unregister push token: $e');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      debugPrint('Could not save push token: $e');
    }
  }

  static void _showInApp(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    showBanner(
      title: n.title ?? 'PALAHI',
      body: n.body ?? '',
      type: message.data['type'] as String? ?? '',
      referenceId: message.data['referenceId'] as String? ?? '',
      route: routeForPush(message.data, _uid),
    );
  }

  /// A banner at the bottom of the screen for a notification that arrives
  /// while the app is open, with a View button that opens [route].
  static void showBanner({
    required String title,
    required String body,
    required String type,
    required String referenceId,
    required String route,
  }) {
    // The messages appear right there in the chat that's open.
    if (type == 'chat' && referenceId == openChatRoomId) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty)
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => AppRouter.router.push(route),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Opens what the push is about.
  static void _open(RemoteMessage message) {
    final route = routeForPush(message.data, _uid);
    // After the first frame, so a cold start's splash screen has built.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppRouter.router.push(route),
    );
  }
}

/// The screen a push opens, from its data payload.
String routeForPush(Map<String, dynamic> data, String? uid) {
  switch (data['type']) {
    case 'booking':
      return '/breeding-requests';
    case 'chat':
      return '/messages';
    case 'breeding':
      return '/breeding-tracker';
    case 'review':
      return uid == null ? '/notifications' : '/reviews/$uid';
    default:
      return '/notifications';
  }
}
