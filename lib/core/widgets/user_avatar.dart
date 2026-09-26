import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// A round profile picture, falling back to the name's first letter when
/// there's no photo or it fails to load.
class UserAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color initialColor;

  const UserAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.radius = 20,
    this.backgroundColor = AppColors.primary,
    this.initialColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      // Drawn over the initial; if it fails to load, the initial shows.
      foregroundImage: imageUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(imageUrl),
      onForegroundImageError: imageUrl.isEmpty ? null : (_, _) {},
      child: Text(
        trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        style: TextStyle(
          color: initialColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
