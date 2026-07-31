import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notification_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/models/notification_model.dart';

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

            error: (e, _) => Center(child: Text(e.toString())),

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

        onTap: () async {
          await ref
              .read(notificationRepositoryProvider)
              .markAsRead(notification.id);
        },
      ),
    );
  }
}
