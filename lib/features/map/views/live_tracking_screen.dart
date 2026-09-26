import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/features/map/viewmodels/trip_map_view_model.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/error_messages.dart';

/// Circular map marker showing the person's photo with a colored ring, or a
/// [fallback] icon badge when they have no photo (or it can't be loaded).
/// Drawn on a canvas so no bundled image asset is needed.
Future<BitmapDescriptor> buildPhotoMarker({
  required String? photoUrl,
  required IconData fallback,
  required Color color,
}) async {
  const size = 132.0;
  const ring = 8.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(size / 2, size / 2);

  canvas.drawCircle(center, size / 2, Paint()..color = color);
  canvas.drawCircle(
    center,
    size / 2 - ring / 2,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  ui.Image? photo;
  if (photoUrl != null && photoUrl.isNotEmpty) {
    try {
      final data = await NetworkAssetBundle(Uri.parse(photoUrl)).load(photoUrl);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 256,
      );
      photo = (await codec.getNextFrame()).image;
    } catch (e) {
      debugPrint('Could not load marker photo: $e');
    }
  }

  const inner = size / 2 - ring;
  if (photo != null) {
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: inner)),
    );
    // Cover-fit the photo into the circle.
    final side = photo.width < photo.height ? photo.width : photo.height;
    final src = Rect.fromCenter(
      center: Offset(photo.width / 2, photo.height / 2),
      width: side.toDouble(),
      height: side.toDouble(),
    );
    canvas.drawImageRect(
      photo,
      src,
      Rect.fromCircle(center: center, radius: inner),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  } else {
    canvas.drawCircle(center, inner, Paint()..color = color);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(fallback.codePoint),
        style: TextStyle(
          fontSize: 64,
          fontFamily: fallback.fontFamily,
          package: fallback.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
  }

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: 52,
    height: 52,
  );
}

/// The breeder's farm photo, falling back to nothing if unset.
Future<String?> fetchBreederPhotoUrl(String breederId) async {
  if (breederId.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('breeders')
        .doc(breederId)
        .get();
    final url = doc.data()?['imageUrl'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final user = await FirebaseFirestore.instance
        .collection('users')
        .doc(breederId)
        .get();
    return user.data()?['imageUrl'] as String?;
  } catch (e) {
    debugPrint('Could not fetch breeder photo: $e');
    return null;
  }
}

/// The farmer's photo. A breeder can't read the farmer's /users doc (rules
/// only allow reading your own), so the photo saved on the booking is the
/// shared source for both sides; the farmer's own profile photo is only a
/// fallback when the farmer is the one viewing.
Future<String?> _farmerPhotoUrl({
  required String farmerId,
  required String bookingPhoto,
  required bool viewerIsFarmer,
  required String? authPhoto,
}) async {
  if (bookingPhoto.isNotEmpty) return bookingPhoto;
  if (!viewerIsFarmer) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(farmerId)
        .get();
    final url = doc.data()?['imageUrl'] as String?;
    if (url != null && url.isNotEmpty) return url;
  } catch (e) {
    debugPrint('Could not fetch farmer photo: $e');
  }
  return authPhoto;
}

/// The breeder's photo as a round avatar (person icon while loading or if
/// they have none).
class BreederPhotoAvatar extends StatelessWidget {
  final String breederId;
  final double radius;

  const BreederPhotoAvatar({
    super.key,
    required this.breederId,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: fetchBreederPhotoUrl(breederId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        final hasPhoto = url != null && url.isNotEmpty;
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.deepOrange.shade100,
          backgroundImage: hasPhoto ? NetworkImage(url) : null,
          child: hasPhoto
              ? null
              : Icon(Icons.person, color: Colors.deepOrange, size: radius),
        );
      },
    );
  }
}

/// The single trip map, shared by both sides so the route, distance and ETA
/// always match: the farmer watches the breeder, and the breeder sees the same
/// route (plus Start Trip / Arrived controls). All state comes from
/// [TripMapViewModel]; this widget only draws it.
class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String breederName;
  final String breederImageUrl;
  final String farmerId;
  final String farmerName;
  final String farmerImageUrl;

  /// Set in the breeder's view: shows a route preview before the trip starts,
  /// plus Start Trip / Arrived.
  final String? breederId;

  const LiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.breederName,
    required this.breederImageUrl,
    required this.farmerId,
    required this.farmerName,
    required this.farmerImageUrl,
    this.breederId,
  });

  bool get isBreeder => breederId != null;

  TripMapArgs get _args => TripMapArgs(
    bookingId: bookingId,
    farmerId: farmerId,
    breederName: breederName,
    breederId: breederId,
  );

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _breederIcon;
  BitmapDescriptor? _farmerIcon;
  String? _breederPhoto;
  String? _farmerPhoto;
  String? _iconsForBreederId;

  /// Loads both people's photos once the trip reveals which breeder it is,
  /// and builds the map markers from them. The same photos feed the info
  /// card, so the farmer and the breeder see identical details.
  void _loadIcons(String breederId) {
    if (_iconsForBreederId == breederId) return;
    _iconsForBreederId = breederId;
    final authPhoto = ref.read(authRepositoryProvider).currentUser?.photoURL;

    fetchBreederPhotoUrl(breederId)
        .then((url) {
          final photo = (url != null && url.isNotEmpty)
              ? url
              : widget.breederImageUrl;
          if (mounted) setState(() => _breederPhoto = photo);
          return buildPhotoMarker(
            photoUrl: photo,
            fallback: Icons.person,
            color: Colors.deepOrange,
          );
        })
        .then((icon) {
          if (mounted) setState(() => _breederIcon = icon);
        });
    _farmerPhotoUrl(
          farmerId: widget.farmerId,
          bookingPhoto: widget.farmerImageUrl,
          viewerIsFarmer: !widget.isBreeder,
          authPhoto: authPhoto,
        )
        .then((url) {
          if (mounted) setState(() => _farmerPhoto = url);
          return buildPhotoMarker(
            photoUrl: url,
            fallback: Icons.home,
            color: Colors.green,
          );
        })
        .then((icon) {
          if (mounted) setState(() => _farmerIcon = icon);
        });
  }

  // Only re-fit when the bounds actually change (e.g. the road route
  // arrives) — fitting on every rebuild kept yanking the camera back while
  // the user was panning or zooming.
  LatLngBounds? _fittedBounds;

  void _fitBounds(LatLngBounds bounds) {
    final controller = _mapController;
    if (controller == null || _fittedBounds == bounds) return;
    _fittedBounds = bounds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    });
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = minLat;
    double minLng = points.first.longitude;
    double maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Widget _message(Widget child) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final vm = ref.read(tripMapViewModelProvider(widget._args).notifier);
    final state = ref.watch(tripMapViewModelProvider(widget._args));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isBreeder
              ? 'Route to ${_displayName(widget.farmerName, 'farmer')}'
              : 'Tracking ${_displayName(widget.breederName, 'breeder')}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: switch (state.status) {
        TripMapStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        TripMapStatus.error => Center(child: Text(state.errorMessage ?? '')),
        TripMapStatus.noFarmPin => _message(
          Text(
            widget.isBreeder
                ? 'This farmer hasn\'t pinned their farm location yet.'
                : 'Pin your farm location in your profile first so the breeder\'s route can be shown here.',
            textAlign: TextAlign.center,
          ),
        ),
        TripMapStatus.noBreederPin => _message(
          Text(
            widget.isBreeder
                ? 'Pin your farm location in your profile first so the route can be shown.'
                : "The breeder hasn't pinned their farm location yet, so the route can't be shown.",
            textAlign: TextAlign.center,
          ),
        ),
        TripMapStatus.waitingForBreeder => _message(
          state.arrived
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_displayName(widget.breederName, 'The breeder')} has arrived at your farm.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrived at ${TimeOfDay.fromDateTime(state.arrivedAt!).format(context)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                )
              : const Text(
                  'The breeder hasn\'t started the trip yet. Check back once they\'re on their way.',
                  textAlign: TextAlign.center,
                ),
        ),
        TripMapStatus.ready => _buildMap(state, vm),
      },
    );
  }

  Widget _buildMap(TripMapState state, TripMapViewModel vm) {
    _loadIcons(state.breederId);
    final farmPoint = state.farmPoint!;
    final breederPoint = state.breederPoint!;
    final roadPoints = state.route?.points;
    final bounds = _boundsOf([breederPoint, farmPoint, ...?roadPoints]);
    _fitBounds(bounds);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: farmPoint, zoom: 13),
          onMapCreated: (controller) {
            _mapController = controller;
            _fitBounds(bounds);
          },
          markers: {
            Marker(
              markerId: const MarkerId('farm'),
              position: farmPoint,
              // Round photo icons are centred on the point; the fallback
              // teardrop points with its tip.
              anchor: _farmerIcon != null
                  ? const Offset(0.5, 0.5)
                  : const Offset(0.5, 1.0),
              icon:
                  _farmerIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
              infoWindow: InfoWindow(
                title: widget.isBreeder
                    ? "${_displayName(widget.farmerName, 'Farmer')}'s Farm"
                    : 'Your Farm',
              ),
            ),
            Marker(
              markerId: const MarkerId('breeder'),
              position: breederPoint,
              anchor: _breederIcon != null
                  ? const Offset(0.5, 0.5)
                  : const Offset(0.5, 1.0),
              icon:
                  _breederIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
              infoWindow: InfoWindow(
                title: _displayName(widget.breederName, 'Breeder'),
                snippet: 'ETA ${state.etaLabel}',
              ),
            ),
          },
          polylines: {
            if (roadPoints != null) ...{
              // White casing under the route line, like Waze.
              Polyline(
                polylineId: const PolylineId('route-casing'),
                points: roadPoints,
                width: 10,
                color: Colors.white,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
              Polyline(
                polylineId: const PolylineId('route'),
                points: roadPoints,
                width: 6,
                color: const Color(0xFF1A73E8),
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            } else
              // No road route yet (or the lookup failed): straight dashed
              // line as a fallback.
              Polyline(
                polylineId: const PolylineId('route'),
                points: [breederPoint, farmPoint],
                width: 5,
                color: Colors.deepOrange,
                patterns: [PatternItem.dash(24), PatternItem.gap(12)],
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
          },
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Identical for both sides: who is driving, whose farm, and the
            // same distance/ETA.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _personTile(
                        role: 'Breeder',
                        name: _displayName(widget.breederName, 'Breeder'),
                        photoUrl: _breederPhoto,
                        fallback: Icons.person,
                        color: Colors.deepOrange,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.grey.shade500,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: _personTile(
                        role: 'Farmer',
                        name: _displayName(widget.farmerName, 'Farmer'),
                        photoUrl: _farmerPhoto,
                        fallback: Icons.home,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.route, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${state.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ETA ${state.etaLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      state.live
                          ? 'On the way'
                          : state.arrived
                          ? 'Arrived'
                          : 'Not started',
                      style: TextStyle(
                        color: state.live
                            ? Colors.teal
                            : state.arrived
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.isBreeder)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: state.live
                ? ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await vm.endTrip().withNetworkTimeout();
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _showError(
                          'Could not mark arrived: ${friendlyError(e)}',
                        );
                      }
                    },
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Arrived'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await vm.startTrip().withNetworkTimeout();
                      } catch (e) {
                        _showError(
                          'Could not start the trip: ${friendlyError(e)}',
                        );
                      }
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Start Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayName(String name, String fallback) =>
      name.trim().isNotEmpty ? name.trim() : fallback;

  Widget _personTile({
    required String role,
    required String name,
    required String? photoUrl,
    required IconData fallback,
    required Color color,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(40),
          backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: hasPhoto ? null : Icon(fallback, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
