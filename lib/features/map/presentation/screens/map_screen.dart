import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/location_service.dart';
import '../../../breeder/data/breeder_repository.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
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
                infoWindow: InfoWindow(title: b.farmName, snippet: 'Rating: ${b.rating}'),
              );
            }).toSet();
          });

          if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
            return const Center(
              child: Text(
                'Google Maps is not supported on Desktop platforms.\nPlease run this app on an Android emulator or iOS simulator.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: cameraPosition,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
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
}
