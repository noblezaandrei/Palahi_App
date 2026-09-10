import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:palahi/features/breeder/data/trip_repository.dart';
import 'package:palahi/features/map/data/farmer_location_repository.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';

/// Farmer-facing screen: shows the breeder's live position (foreground
/// tracking, updates while the breeder has the trip started) alongside the
/// farmer's own pinned location, with a straight connecting line and live
/// distance — no turn-by-turn routing, this app has no routing API wired up.
class LiveTrackingScreen extends ConsumerWidget {
  final String bookingId;
  final String breederName;

  const LiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.breederName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final tripAsync = ref.watch(tripLocationStreamProvider(bookingId));
    final farmLocationAsync = ref.watch(farmerLocationProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking $breederName'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: farmLocationAsync.when(
        data: (farmLocation) {
          if (farmLocation == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Pin your farm location in your profile first so the breeder\'s route can be shown here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return tripAsync.when(
            data: (trip) {
              if (trip == null || !trip.active) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'The breeder hasn\'t started the trip yet. Check back once they\'re on their way.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final farmPoint = LatLng(
                farmLocation.latitude,
                farmLocation.longitude,
              );
              final breederPoint = LatLng(trip.latitude, trip.longitude);
              final distanceKm = LocationUtils.getDistanceKm(
                breederPoint.latitude,
                breederPoint.longitude,
                farmPoint.latitude,
                farmPoint.longitude,
              );

              final bounds = LatLngBounds.fromPoints([farmPoint, breederPoint]);

              return Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(60),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.palahi',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [farmPoint, breederPoint],
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: farmPoint,
                            width: 60,
                            height: 60,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.home,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          Marker(
                            point: breederPoint,
                            width: 60,
                            height: 60,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pets,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$breederName is ${distanceKm.toStringAsFixed(1)} km away',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading trip: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading your farm location: $e')),
      ),
    );
  }
}
