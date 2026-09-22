import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:palahi/features/map/repositories/location_service.dart';
import 'package:palahi/features/map/repositories/farmer_location_repository.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/stud_pig_repository.dart';
import 'package:palahi/features/breeder/repositories/review_repository.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/breeder/models/stud_pig_model.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/views/chat_room_screen.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/repositories/trip_repository.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/map/views/live_tracking_screen.dart';
import 'package:palahi/features/map/repositories/route_service.dart';
import 'package:palahi/features/map/views/widgets/active_trip_banner.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  // Guards against a duplicate/stacked page push — e.g. a marker tap firing
  // twice (a known google_maps_flutter web quirk).
  bool _isSheetOpen = false;

  // The breeder whose tap-preview card is currently showing, if any. A
  // plain in-Stack widget (not a separately-routed dialog/bottom sheet) —
  // those get their clicks swallowed by the live map on web, the same bug
  // the full-page breeder detail view already works around.
  BreederModel? _tappedBreeder;

  // Whether the farmer's own tap-preview card (their profile photo/name) is
  // currently showing. Mutually exclusive with _tappedBreeder — only one
  // preview card is shown at a time.
  bool _tappedFarm = false;

  // Live-trip overlay state: the breeder's photo marker, the last road route
  // (kept while the next one loads) and whether the camera has been fitted
  // to the current trip.
  GoogleMapController? _mapController;
  BitmapDescriptor? _tripBreederIcon;
  String? _tripIconBreederId;
  RoadRoute? _lastTripRoute;
  String? _fittedTripId;

  // Google's InfoWindow can only ever have one open at a time across the
  // whole map, so it can't be (ab)used to keep every pin's name visible at
  // once. To get always-on name tags like Google's own place labels, we bake
  // the label text directly into each marker's icon bitmap instead — cached
  // here by a stable key so we don't regenerate on every rebuild.
  final Map<String, BitmapDescriptor> _labeledMarkerCache = {};
  final Set<String> _pendingLabeledMarkers = {};

  Future<void> _ensureLabeledMarker({
    required String cacheKey,
    required String label,
    required Color pinColor,
  }) async {
    if (_labeledMarkerCache.containsKey(cacheKey) ||
        _pendingLabeledMarkers.contains(cacheKey)) {
      return;
    }
    _pendingLabeledMarkers.add(cacheKey);
    final icon = await _buildLabeledMarkerIcon(
      label: label,
      pinColor: pinColor,
    );
    _pendingLabeledMarkers.remove(cacheKey);
    if (!mounted) return;
    setState(() => _labeledMarkerCache[cacheKey] = icon);
  }

  Future<BitmapDescriptor> _buildLabeledMarkerIcon({
    required String label,
    required Color pinColor,
  }) async {
    const double pixelRatio = 2.5;
    const double pinDiameter = 26;
    const double pinBorder = 3;
    const double gap = 4;
    const double paddingH = 10;
    const double paddingV = 5;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220);

    final double chipWidth = textPainter.width + paddingH * 2;
    final double chipHeight = textPainter.height + paddingV * 2;
    final double logicalWidth = chipWidth > pinDiameter
        ? chipWidth
        : pinDiameter;
    final double logicalHeight = chipHeight + gap + pinDiameter;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final chipRect = Rect.fromLTWH(
      (logicalWidth - chipWidth) / 2,
      0,
      chipWidth,
      chipHeight,
    );
    final chipRRect = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(6),
    );
    canvas.drawShadow(Path()..addRRect(chipRRect), Colors.black, 1.5, false);
    canvas.drawRRect(chipRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      chipRRect,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      Offset(chipRect.left + paddingH, chipRect.top + paddingV),
    );

    final pinCenter = Offset(
      logicalWidth / 2,
      chipHeight + gap + pinDiameter / 2,
    );
    canvas.drawCircle(
      pinCenter,
      pinDiameter / 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      pinCenter,
      pinDiameter / 2 - pinBorder / 2,
      Paint()..color = pinColor,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * pixelRatio).round(),
      (logicalHeight * pixelRatio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: logicalWidth,
      height: logicalHeight,
    );
  }

  void _ensureTripIcon(String breederId) {
    if (_tripIconBreederId == breederId) return;
    _tripIconBreederId = breederId;
    fetchBreederPhotoUrl(breederId)
        .then(
          (url) => buildPhotoMarker(
            photoUrl: url,
            fallback: Icons.person,
            color: Colors.deepOrange,
          ),
        )
        .then((icon) {
          if (mounted) setState(() => _tripBreederIcon = icon);
        });
  }

  void _fitTripOnce(String tripId, LatLng a, LatLng b) {
    if (_fittedTripId == tripId) return;
    final controller = _mapController;
    if (controller == null) return;
    _fittedTripId = tripId;
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final locationAsyncValue = ref.watch(currentLocationProvider);
    final farmLocationAsync = user == null
        ? const AsyncValue<FarmerLocation?>.data(null)
        : ref.watch(farmerLocationProvider(user.uid));
    final breedersAsyncValue = ref.watch(breedersStreamProvider);
    final pigsAsyncValue = ref.watch(allAvailablePigsProvider);

    final allPigs = pigsAsyncValue.value ?? [];

    // A breeder currently heading to this farmer, if any. Their live GPS
    // position is what the Map tab must show — not their stored farm address.
    BreedingRequestModel? tripRequest;
    TripLocation? activeTrip;
    if (user != null) {
      final requests = ref.watch(farmerRequestsProvider(user.uid)).value ?? [];
      for (final r in requests.where((r) => r.status == 'accepted')) {
        final t = ref.watch(tripLocationStreamProvider(r.id)).value;
        if (activeTrip == null && t != null && t.active) {
          tripRequest = r;
          activeTrip = t;
        }
      }
    }
    final farmPin = farmLocationAsync.value;
    LatLng? tripBreederPoint;
    LatLng? tripFarmPoint;
    RoadRoute? tripRoute;
    if (activeTrip != null && farmPin != null) {
      // The breeder's pinned farm location — the same point their normal
      // marker uses — rather than the phone's live GPS.
      for (final b in breedersAsyncValue.value ?? const <BreederModel>[]) {
        if (b.id == activeTrip.breederId &&
            (b.latitude != 0.0 || b.longitude != 0.0)) {
          tripBreederPoint = LatLng(b.latitude, b.longitude);
        }
      }
      tripFarmPoint = LatLng(farmPin.latitude, farmPin.longitude);
      if (tripBreederPoint != null) {
        final routeAsync = ref.watch(
          tripRouteProvider(routeKeyFor(tripBreederPoint, tripFarmPoint)),
        );
        if (routeAsync.value != null) _lastTripRoute = routeAsync.value;
        tripRoute = _lastTripRoute;
        _ensureTripIcon(activeTrip.breederId);
        _fitTripOnce(tripRequest!.id, tripBreederPoint, tripFarmPoint);
      }
    } else {
      _lastTripRoute = null;
      _fittedTripId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeders Map (Camalig, Albay)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: (() {
        // Prefer the farmer's pinned farm location over live GPS, so the
        // "nearest breeder" calculation and marker reflect where they
        // actually set their farm to be, not wherever the device currently
        // is.
        final pinnedLocation = farmLocationAsync.value;
        final usingPin = pinnedLocation != null;
        final center = pinnedLocation != null
            ? LatLng(pinnedLocation.latitude, pinnedLocation.longitude)
            : locationAsyncValue.when(
                data: (pos) => LatLng(pos.latitude, pos.longitude),
                loading: () => const LatLng(
                  LocationUtils.camaligCenterLatitude,
                  LocationUtils.camaligCenterLongitude,
                ),
                error: (err, stack) => const LatLng(
                  LocationUtils.camaligCenterLatitude,
                  LocationUtils.camaligCenterLongitude,
                ),
              );

        return breedersAsyncValue.when(
          data: (breeders) {
            // 1. Every breeder with a pinned location appears on the map
            final camaligBreeders = breeders
                .where((b) => b.latitude != 0.0 || b.longitude != 0.0)
                .toList();

            // 2. Identify the nearest breeder inside Camalig, Albay
            BreederModel? nearestBreeder;
            double minDistance = double.infinity;

            for (var b in camaligBreeders) {
              final dist = LocationUtils.getDistanceKm(
                center.latitude,
                center.longitude,
                b.latitude,
                b.longitude,
              );
              if (dist < minDistance) {
                minDistance = dist;
                nearestBreeder = b;
              }
            }

            // 3. Construct map markers. Google Maps markers can't embed
            // arbitrary widgets like flutter_map's could, and its built-in
            // InfoWindow can only ever have one open at a time across the
            // whole map — no good for keeping every pin's name visible at
            // once. So each marker's name is baked into its icon bitmap
            // instead (see _buildLabeledMarkerIcon), always visible like a
            // Google Maps place label, with color still distinguishing
            // farmer vs. nearest breeder vs. other breeders. Tapping a
            // breeder marker additionally shows a richer preview card
            // (below) with their photo and rating.
            final markers = camaligBreeders
                .where((b) => b.id != activeTrip?.breederId)
                .map((b) {
                  final isNearest =
                      nearestBreeder != null && nearestBreeder.id == b.id;
                  final cacheKey = 'breeder_${b.id}';
                  final pinColor = isNearest
                      ? Colors.amber.shade700
                      : Colors.green;

                  _ensureLabeledMarker(
                    cacheKey: cacheKey,
                    label: b.farmName,
                    pinColor: pinColor,
                  );

                  return Marker(
                    markerId: MarkerId(b.id),
                    position: LatLng(b.latitude, b.longitude),
                    icon:
                        _labeledMarkerCache[cacheKey] ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          isNearest
                              ? BitmapDescriptor.hueYellow
                              : BitmapDescriptor.hueGreen,
                        ),
                    onTap: () => setState(() {
                      _tappedBreeder = b;
                      _tappedFarm = false;
                    }),
                  );
                })
                .toSet();

            // The travelling breeder's live position, with their photo.
            if (tripBreederPoint != null) {
              markers.add(
                Marker(
                  markerId: const MarkerId('trip_breeder'),
                  position: tripBreederPoint,
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: 2,
                  icon:
                      _tripBreederIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                  infoWindow: InfoWindow(
                    title: tripRequest!.breederName,
                    snippet: tripRoute == null
                        ? 'On the way'
                        : 'ETA ${formatTripDuration(tripRoute.duration)}',
                  ),
                ),
              );
            }

            // Add farmer's reference point marker — their pinned farm
            // location when set, otherwise their live GPS position.
            const farmCacheKey = 'farm_location';
            final farmLabel = usingPin ? 'Your Farm' : 'You are here';
            _ensureLabeledMarker(
              cacheKey: farmCacheKey,
              label: farmLabel,
              pinColor: AppColors.primary,
            );
            markers.add(
              Marker(
                markerId: const MarkerId('current_location'),
                position: center,
                icon:
                    _labeledMarkerCache[farmCacheKey] ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                // No native InfoWindow — tapping shows a richer preview card
                // (below) with the farmer's own profile photo instead, same
                // pattern as the breeder markers.
                onTap: () => setState(() {
                  _tappedFarm = true;
                  _tappedBreeder = null;
                }),
              ),
            );

            // 4. Render stack with map and floating nearest breeder card
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: markers,
                ),

                // Live trip banner: a breeder is on their way to this farmer.
                if (user != null)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: ActiveTripBanner(farmerId: user.uid),
                  ),

                // Floating Highlight Card for Nearest Breeder
                if (nearestBreeder != null &&
                    _tappedBreeder == null &&
                    !_tappedFarm)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.amber.shade100,
                              child: const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'NEAREST STUD BREEDER',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    nearestBreeder.farmName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${minDistance.toStringAsFixed(1)} km away within Camalig, Albay',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _openBreederDetailPage(
                                  context,
                                  ref,
                                  nearestBreeder!,
                                  allPigs,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                // Override the app-wide theme's full-width
                                // (infinite) minimumSize — that default only
                                // makes sense for buttons in a bounded
                                // column/form; inside this Row it collides
                                // with the Row's unbounded width for
                                // non-flex children and crashes layout.
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('View Details'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Tap-preview card for whichever breeder marker was tapped
                if (_tappedBreeder != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildBreederPreviewCard(
                      context,
                      ref,
                      _tappedBreeder!,
                      allPigs,
                    ),
                  ),

                // Tap-preview card for the farmer's own pin
                if (_tappedFarm)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildFarmPreviewCard(context, ref, farmLabel),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Error loading breeders: $err')),
        );
      })(),
    );
  }

  Widget _buildBreederPreviewCard(
    BuildContext context,
    WidgetRef ref,
    BreederModel breeder,
    List<StudPigModel> allPigs,
  ) {
    final rating = ref.watch(breederRatingProvider(breeder.id));

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: breeder.imageUrl.isNotEmpty
                  ? NetworkImage(breeder.imageUrl)
                  : null,
              child: breeder.imageUrl.isEmpty
                  ? const Icon(Icons.storefront, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    breeder.farmName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating.count > 0
                            ? '${rating.average.toStringAsFixed(1)} (${rating.count})'
                            : 'New',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Close',
              onPressed: () => setState(() => _tappedBreeder = null),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _tappedBreeder = null);
                _openBreederDetailPage(context, ref, breeder, allPigs);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                // See _MapScreenState build() — the theme's default
                // full-width minimumSize crashes layout inside a Row.
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmPreviewCard(
    BuildContext context,
    WidgetRef ref,
    String farmLabel,
  ) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final name = (profile?['name'] as String?)?.trim();
    final imageUrl = profile?['imageUrl'] as String? ?? '';
    final municipality = (profile?['municipality'] as String?)?.trim();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name != null && name.isNotEmpty ? name : farmLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    municipality != null && municipality.isNotEmpty
                        ? municipality
                        : farmLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Close',
              onPressed: () => setState(() => _tappedFarm = false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBreederDetailPage(
    BuildContext context,
    WidgetRef ref,
    BreederModel breeder,
    List<StudPigModel> allPigs,
  ) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    final breederPigs = allPigs
        .where((p) => p.breederId == breeder.id)
        .toList();
    final rating = ref.read(breederRatingProvider(breeder.id));

    // A translucent bottom sheet floating over a *live* Google Map is a
    // known bad combination on Flutter web: the map is a real native
    // browser element in its own layer, and it can keep swallowing clicks
    // in that screen region even where a Flutter overlay is painted on top
    // of it — including the sheet's own close button. Pushing a full opaque
    // page instead avoids the map being interactive underneath at all.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(breeder.farmName)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            breeder.farmName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Address: ${breeder.location.isNotEmpty ? breeder.location : "Not specified"}',
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.count > 0
                                ? rating.average.toStringAsFixed(1)
                                : 'New',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Services: ${breeder.services.join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available Pigs Count: ${breederPigs.length}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),

                // Show pig images
                if (breederPigs.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: breederPigs.length,
                      itemBuilder: (context, index) {
                        final pig = breederPigs[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Chip(
                            avatar: pig.imageUrl.isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(pig.imageUrl),
                                  )
                                : const CircleAvatar(
                                    child: Icon(Icons.pets, size: 12),
                                  ),
                            label: Text(
                              pig.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/breeder/${breeder.id}');
                        },
                        icon: const Icon(Icons.storefront),
                        label: const Text('View Profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);

                          final currentUser = ref
                              .read(authRepositoryProvider)
                              .currentUser;
                          final profile = ref
                              .read(currentUserProfileProvider)
                              .value;
                          final role = profile != null
                              ? profile['role'] as String? ?? 'farmer'
                              : 'farmer';

                          if (currentUser == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please log in to send a message.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          if (role != 'farmer') {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Only farmers can initiate messages to breeders.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          final farmerName = profile != null
                              ? profile['name'] as String? ?? 'Farmer'
                              : currentUser.displayName ?? 'Farmer';

                          try {
                            final roomId = await ref
                                .read(chatRepositoryProvider)
                                .getOrCreateChatRoom(
                                  farmerId: currentUser.uid,
                                  farmerName: farmerName,
                                  breederId: breeder.id,
                                  breederName: breeder.farmName,
                                );

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatRoomScreen(
                                    roomId: roomId,
                                    otherParticipantName: breeder.farmName,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Message failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);

                          if (breeder.latitude == 0.0 &&
                              breeder.longitude == 0.0) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This breeder has not provided a location yet.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          final currentLocation = ref
                              .read(currentLocationProvider)
                              .value;
                          final origin = currentLocation != null
                              ? '${currentLocation.latitude},${currentLocation.longitude}'
                              : null;

                          final url = Uri.parse(
                            origin != null
                                ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=${breeder.latitude},${breeder.longitude}'
                                : 'https://www.google.com/maps/search/?api=1&query=${breeder.latitude},${breeder.longitude}',
                          );

                          final launched = await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched && context.mounted) {
                            final fallback = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${breeder.latitude},${breeder.longitude}',
                            );
                            final fallbackLaunched = await launchUrl(
                              fallback,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!fallbackLaunched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open the breeder location.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text('Directions'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _isSheetOpen = false;
  }
}
