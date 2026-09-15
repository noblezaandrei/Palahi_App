import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Opens a full-screen, pinch-to-zoom view of [imageUrl].
void showFullScreenImage(BuildContext context, String imageUrl) {
  if (imageUrl.isEmpty) return;

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FullScreenImagePage(imageUrl: imageUrl),
        );
      },
    ),
  );
}

class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular "view full picture" affordance meant to sit in a
/// [Stack] positioned over a pig's thumbnail image.
class ViewFullImageButton extends StatelessWidget {
  final String imageUrl;

  const ViewFullImageButton({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(140),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showFullScreenImage(context, imageUrl),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.zoom_in, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
