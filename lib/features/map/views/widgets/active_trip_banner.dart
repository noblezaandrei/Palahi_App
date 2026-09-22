import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/repositories/trip_repository.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/map/repositories/farmer_location_repository.dart';
import 'package:palahi/features/map/repositories/route_service.dart';
import 'package:palahi/features/map/viewmodels/trip_map_view_model.dart';
import 'package:palahi/features/map/views/live_tracking_screen.dart';

/// Eye-catching card shown to a farmer whenever a breeder is on the way,
/// with the breeder's photo, distance and arrival time. Tapping it opens the
/// trip map. Renders nothing when no trip is active.
class ActiveTripBanner extends ConsumerWidget {
  final String farmerId;

  const ActiveTripBanner({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(farmerRequestsProvider(farmerId)).value ?? [];
    final accepted = requests.where((r) => r.status == 'accepted').toList();
    if (accepted.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [for (final request in accepted) _TripBannerItem(request)],
    );
  }
}

class _TripBannerItem extends ConsumerStatefulWidget {
  final BreedingRequestModel request;

  const _TripBannerItem(this.request);

  @override
  ConsumerState<_TripBannerItem> createState() => _TripBannerItemState();
}

class _TripBannerItemState extends ConsumerState<_TripBannerItem> {
  RoadRoute? _lastRoute;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final trip = ref.watch(tripLocationStreamProvider(request.id)).value;
    if (trip == null || !trip.active) return const SizedBox.shrink();

    // Same pinned-to-pinned route as the trip map, so the numbers match.
    final farm = ref.watch(farmerLocationProvider(request.farmerId)).value;
    LatLng? breederPoint;
    for (final b in ref.watch(breedersStreamProvider).value ?? []) {
      if (b.id == request.breederId &&
          (b.latitude != 0.0 || b.longitude != 0.0)) {
        breederPoint = LatLng(b.latitude, b.longitude);
      }
    }
    if (farm != null && breederPoint != null) {
      final route = ref
          .watch(
            tripRouteProvider(
              routeKeyFor(breederPoint, LatLng(farm.latitude, farm.longitude)),
            ),
          )
          .value;
      if (route != null) _lastRoute = route;
    }
    final route = _lastRoute;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.deepOrange, width: 1.5),
      ),
      child: ListTile(
        leading: BreederPhotoAvatar(breederId: request.breederId, radius: 24),
        title: Text(
          '${request.breederName} is on the way',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          route == null
              ? 'Tap to track the trip'
              : '${route.distanceKm.toStringAsFixed(1)} km · arrives in ${formatTripDuration(route.duration)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveTrackingScreen(
              bookingId: request.id,
              breederName: request.breederName,
              farmerId: request.farmerId,
            ),
          ),
        ),
      ),
    );
  }
}
