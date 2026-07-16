import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          _buildNotificationItem(
            context,
            icon: Icons.star,
            title: 'New review on',
            subtitle: 'Green Valley Farms',
            time: '2 minutes ago',
            isUnread: true,
          ),
          _buildNotificationItem(
            context,
            icon: Icons.message,
            title: 'Your message was sent to',
            subtitle: 'Lucky 7 Genetics',
            time: '10 minutes ago',
            isUnread: true,
          ),
          _buildNotificationItem(
            context,
            icon: Icons.photo_camera,
            title: 'Triple A Hog Farm',
            subtitle: 'added new photos',
            time: '1 hour ago',
            isUnread: false,
          ),
          _buildNotificationItem(
            context,
            icon: Icons.info,
            title: 'Quality Genetics PH',
            subtitle: 'updated their information',
            time: '2 hours ago',
            isUnread: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      color: isUnread ? AppColors.primaryBackground : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isUnread ? AppColors.primaryLight.withAlpha(50) : Colors.grey.shade200,
          child: Icon(icon, color: isUnread ? AppColors.primary : Colors.grey),
        ),
        title: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(text: '$title '),
              TextSpan(
                text: subtitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
