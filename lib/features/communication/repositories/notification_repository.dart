import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../../auth/repositories/auth_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

final userNotificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
      // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
      // a permission-denied error during logout stays cached empty forever.
      ref.watch(authStateProvider);
      return ref.watch(notificationRepositoryProvider).getNotifications(userId);
    });

// Excludes chat notifications — those get their own badge on the message
// icon (unreadChatNotificationCountProvider) instead of double-counting
// here too.
final unreadNotificationCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  ref.watch(authStateProvider);
  return ref
      .watch(notificationRepositoryProvider)
      .getNotifications(userId)
      .map(
        (notifications) =>
            notifications.where((n) => !n.isRead && n.type != 'chat').length,
      );
});

final unreadChatNotificationCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  ref.watch(authStateProvider);
  return ref
      .watch(notificationRepositoryProvider)
      .getNotifications(userId)
      .map(
        (notifications) =>
            notifications.where((n) => !n.isRead && n.type == 'chat').length,
      );
});

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository(this._firestore);

  // Same guarded pattern as every other stream in the app: on sign-out the
  // query is denied, and an unguarded stream surfaces that as an uncaught
  // error instead of just emptying the list.
  Stream<List<NotificationModel>> getNotifications(String userId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => NotificationModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load notifications: $error');
      yield <NotificationModel>[];
    }
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> createNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').add(notification.toJson());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Clears the message badge — called when the user opens their inbox,
  /// since individual chat notifications aren't linked to a specific room.
  Future<void> markChatNotificationsAsRead(String userId) async {
    final unread = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'chat')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Clears the message badge for one conversation — called while that
  /// chat is open, so messages you're already reading don't pile up unread.
  Future<void> markChatRoomNotificationsAsRead(
    String userId,
    String roomId,
  ) async {
    final unread = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'chat')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    var any = false;
    for (final doc in unread.docs) {
      if (doc.data()['referenceId'] == roomId) {
        batch.update(doc.reference, {'isRead': true});
        any = true;
      }
    }
    if (any) await batch.commit();
  }

  /// Deletes all of the user's notifications (Firestore batches max out at
  /// 500 writes, so it goes in chunks).
  Future<void> clearAll(String userId) async {
    final all = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();
    for (var i = 0; i < all.docs.length; i += 450) {
      final batch = _firestore.batch();
      for (final doc in all.docs.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
