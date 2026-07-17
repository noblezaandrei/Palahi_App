import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/location_service.dart';
import '../../../breeder/data/breeder_repository.dart';
import '../../../breeder/data/stud_pig_repository.dart';
import '../../../breeder/domain/models/breeder_model.dart';
import '../../../breeder/domain/models/stud_pig_model.dart';
import '../../../../core/constants/colors.dart';
import 'package:go_router/go_router.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? mapController;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final locationAsyncValue = ref.watch(currentLocationProvider);
    final breedersAsyncValue = ref.watch(breedersStreamProvider);
    final pigsAsyncValue = ref.watch(allAvailablePigsProvider);

    final allPigs = pigsAsyncValue.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeders Map'),
      ),
      body: locationAsyncValue.when(
        data: (position) {
          final cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 12.0,
          );

          Set<Marker> markers = {};
          
          breedersAsyncValue.whenData((breeders) {
            markers = breeders.map((b) {
              return Marker(
                markerId: MarkerId(b.id),
                position: LatLng(b.latitude, b.longitude),
                infoWindow: InfoWindow(
                  title: b.farmName,
                  snippet: 'Rating: ${b.rating} • Services: ${b.services.join(", ")}',
                ),
                onTap: () {
                  _showBreederBottomSheet(context, ref, b, allPigs);
                },
              );
            }).toSet();
          });

          // Check if Google Maps is supported (not Windows desktop)
          final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

          if (isDesktop) {
            return breedersAsyncValue.when(
              data: (breeders) => _buildDesktopSimulatedMap(context, breeders, allPigs),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            );
          }

          return GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: cameraPosition,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error getting location: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(currentLocationProvider),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }

  // A beautiful interactive mock map representing GIS pins on desktop
  Widget _buildDesktopSimulatedMap(BuildContext context, List<BreederModel> breeders, List<StudPigModel> allPigs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
      ),
      child: Stack(
        children: [
          // Stylized GIS map grid lines
          Positioned.fill(
            child: GridPaper(
              color: Colors.blue.withAlpha(20),
              divisions: 2,
              interval: 100,
              subdivisions: 4,
            ),
          ),
          
          // Stylized background graphics
          Center(
            child: Icon(
              Icons.map,
              size: 200,
              color: Colors.white.withAlpha(10),
            ),
          ),
          
          const Positioned(
            top: 16,
            left: 16,
            child: Card(
              color: Colors.black54,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.desktop_windows, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Simulated GIS Map Mode (Windows)',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Interactive pins corresponding to breeder records
          ...breeders.asMap().entries.map((entry) {
            final idx = entry.key;
            final b = entry.value;

            // Generate deterministic positioning for visualization on desktop
            final double left = 100.0 + (idx * 160.0) % 500;
            final double top = 120.0 + (idx * 110.0) % 350;

            return Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () => _showBreederBottomSheet(context, ref, b, allPigs),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Text(
                        b.farmName,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showBreederBottomSheet(BuildContext context, WidgetRef ref, BreederModel breeder, List<StudPigModel> allPigs) {
    final breederPigs = allPigs.where((p) => p.breederId == breeder.id).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Address: ${breeder.location.isNotEmpty ? breeder.location : "Not specified"}'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        breeder.rating.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Services: ${breeder.services.join(', ')}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Available Pigs Count: ${breederPigs.length}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (breederPigs.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: breederPigs.length,
                  itemBuilder: (context, index) {
                    final pig = breederPigs[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        avatar: pig.imageUrl.isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(pig.imageUrl))
                            : const CircleAvatar(child: Icon(Icons.pets, size: 12)),
                        label: Text(pig.name, style: const TextStyle(fontSize: 11)),
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
                      context.push('/messages');
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message Breeder'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${breeder.latitude},${breeder.longitude}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open directions link')),
                        );
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
    );
  }
}
