import 'package:flutter/material.dart';

/// An IconButton with a small red unread-count badge, used for the message
/// and notification icons across the app's headers.
class BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color iconColor;
  final VoidCallback onPressed;
  final String? tooltip;

  const BadgeIconButton({
    super.key,
    required this.icon,
    required this.count,
    required this.onPressed,
    this.iconColor = Colors.black,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
