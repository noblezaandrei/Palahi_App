import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/communication/models/notification_model.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/views/chat_room_screen.dart';
import 'package:palahi/features/communication/views/messaging_screen.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/views/breeder_history_screen.dart';
import 'package:palahi/core/utils/error_messages.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          if ((ref
                      .watch(
                        userNotificationsProvider(
                          ref.watch(authRepositoryProvider).currentUser?.uid ??
                              '',
                        ),
                      )
                      .value ??
                  const [])
              .isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearAll(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final user = ref.watch(authRepositoryProvider).currentUser;

          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          final notifications = ref.watch(userNotificationsProvider(user.uid));

          return notifications.when(
            loading: () => const Center(child: CircularProgressIndicator()),

            error: (e, _) => Center(child: Text(friendlyError(e))),

            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No notifications yet'));
              }

              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final notification = list[index];

                  return _buildNotificationItem(
                    context,
                    notification: notification,
                    ref: ref,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          "This removes all your notifications. It can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .clearAll(uid)
          .withNetworkTimeout();
      messenger.showSnackBar(
        const SnackBar(content: Text('Notifications cleared.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not clear notifications: ${friendlyError(e)}'),
        ),
      );
    }
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required NotificationModel notification,
    required WidgetRef ref,
  }) {
    IconData icon = Icons.notifications;

    switch (notification.type) {
      case 'booking':
        icon = Icons.pets;
        break;

      case 'chat':
        icon = Icons.message;
        break;

      case 'review':
        icon = Icons.star;
        break;
    }

    return Container(
      color: notification.isRead
          ? Colors.transparent
          : AppColors.primaryBackground,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),

        leading: CircleAvatar(
          backgroundColor: notification.isRead
              ? Colors.grey.shade200
              : AppColors.primaryLight.withAlpha(50),
          child: Icon(
            icon,
            color: notification.isRead ? Colors.grey : AppColors.primary,
          ),
        ),

        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              '${notification.createdAt.day}/${notification.createdAt.month}/${notification.createdAt.year}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),

        trailing: notification.isRead
            ? null
            : const Icon(Icons.circle, color: Colors.blue, size: 10),

        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationRepositoryProvider)
                .markAsRead(notification.id)
                .catchError((Object e) {
                  debugPrint('Failed to mark notification read: $e');
                });
          }
          _openNotificationTarget(context, ref, notification);
        },
      ),
    );
  }

  /// Takes the user to whatever the notification is about.
  Future<void> _openNotificationTarget(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    switch (notification.type) {
      case 'booking':
        await _openBooking(context, ref, notification.referenceId);
        break;

      case 'chat':
        await _openChat(context, ref, uid, notification.referenceId);
        break;

      case 'review':
        context.push('/reviews/$uid');
        break;
    }
  }

  /// Active bookings live on the requests screen ("Manage Incoming
  /// Requests" for breeders, "My Breeding Requests" for farmers); finished
  /// ones only show up in history, which is also where farmers leave reviews.
  Future<void> _openBooking(
    BuildContext context,
    WidgetRef ref,
    String bookingId,
  ) async {
    String? status;
    if (bookingId.isNotEmpty) {
      try {
        status = await ref
            .read(breedingRequestRepositoryProvider)
            .getRequestStatus(bookingId);
      } catch (e) {
        debugPrint('Failed to look up booking $bookingId: $e');
      }
    }
    if (!context.mounted) return;

    if (status != null && terminalBookingStatuses.contains(status)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BreedingHistoryScreen()),
      );
    } else {
      context.push('/breeding-requests');
    }
  }

  /// Opens the conversation the message came from, or the inbox if the room
  /// can't be found (e.g. notifications from before rooms were recorded).
  Future<void> _openChat(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String roomId,
  ) async {
    ChatRoomModel? room;
    String role = 'farmer';
    if (roomId.isNotEmpty) {
      try {
        final rooms = await ref.read(chatRoomsStreamProvider(uid).future);
        for (final r in rooms) {
          if (r.id == roomId) {
            room = r;
            break;
          }
        }
        role = getChatInboxRole(
          await ref.read(currentUserProfileProvider.future),
        );
      } catch (e) {
        debugPrint('Failed to look up chat room $roomId: $e');
      }
    }
    if (!context.mounted) return;

    if (room == null) {
      context.push('/messages');
      return;
    }

    final otherParticipantName = getOtherParticipantName(
      room: room,
      role: role,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: roomId,
          otherParticipantName: otherParticipantName,
        ),
      ),
    );
  }
}
