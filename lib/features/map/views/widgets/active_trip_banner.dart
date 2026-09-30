import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/features/breeder/repositories/breeding_request_repository.dart';
import 'package:palahi/features/breeder/repositories/trip_repository.dart';
import 'package:palahi/features/breeder/models/breeding_request_model.dart';
import 'package:palahi/features/map/viewmodels/trip_map_view_model.dart';
import 'package:palahi/features/map/views/live_tracking_screen.dart';
import 'package:palahi/core/l10n/app_strings.dart';

/// Eye-catching card shown to a farmer whenever a breeder is on the way,
/// with the breeder's photo, distance and arrival time. Tapping it opens the
/// trip map. Renders nothing otherwise (arrivals are shown on the farmer's
/// My Breeding Requests screen).
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
  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final trip = ref.watch(tripLocationStreamProvider(request.id)).value;
    if (trip == null) return const SizedBox.shrink();
    // Once the breeder has arrived, the arrival notice lives on the
    // farmer's My Breeding Requests card instead of here.
    if (!trip.active) return const SizedBox.shrink();

    // The trip map's own state, so the numbers match it exactly.
    final state = ref.watch(
      tripMapViewModelProvider(
        TripMapArgs(
          bookingId: request.id,
          farmerId: request.farmerId,
          breederName: request.breederName,
        ),
      ),
    );
    final ready = state.status == TripMapStatus.ready;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: Colors.deepOrange.withAlpha(80),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTrip(context, request),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFF4511E), Color(0xFFFF8A50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: BreederPhotoAvatar(
                    breederId: request.breederId,
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('ON THE WAY TO YOUR FARM'),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.breederName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        !ready
                            ? tr('Tap to track the trip')
                            : tr('{km} km away · arrives in {eta}', {
                                'km': state.distanceKm.toStringAsFixed(1),
                                'eta': state.etaLabel,
                              }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('Track'),
                    style: TextStyle(
                      color: Color(0xFFF4511E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTrip(BuildContext context, BreedingRequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingScreen(
          bookingId: request.id,
          breederName: request.breederName,
          breederImageUrl: request.breederImageUrl,
          farmerId: request.farmerId,
          farmerName: request.farmerName,
          farmerImageUrl: request.farmerImageUrl,
        ),
      ),
    );
  }
}
