import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/location_service.dart';
import '../../../breeder/data/breeder_repository.dart';
import '../../../breeder/data/stud_pig_repository.dart';
import '../../../breeder/domain/models/breeder_model.dart';
import '../../../breeder/domain/models/stud_pig_model.dart';
import '../../../communication/data/chat_repository.dart';
import '../../../communication/presentation/screens/chat_room_screen.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/location_utils.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final locationAsyncValue = ref.watch(currentLocationProvider);
    final breedersAsyncValue = ref.watch(breedersStreamProvider);
    final pigsAsyncValue = ref.watch(allAvailablePigsProvider);

    final allPigs = pigsAsyncValue.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeders Map (Camalig, Albay)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: (() {
        final center = locationAsyncValue.when(
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
            // 1. Filter breeders to only those located in Camalig, Albay
            final camaligBreeders = breeders.where((b) {
              return LocationUtils.isInCamaligAlbay(b.latitude, b.longitude);
            }).toList();

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

            // 3. Construct map markers
            final markers = camaligBreeders.map((b) {
              final isNearest = nearestBreeder != null && nearestBreeder.id == b.id;
              
              return Marker(
                point: LatLng(b.latitude, b.longitude),
                width: 100,
                height: 80,
                child: GestureDetector(
                  onTap: () {
                    _showBreederBottomSheet(context, ref, b, allPigs);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNearest ? Colors.amber : AppColors.primaryLight,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          b.farmName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isNearest ? Icons.star : Icons.location_on,
                        color: isNearest ? Colors.amber : AppColors.primary,
                        size: isNearest ? 36 : 30,
                      ),
                    ],
                  ),
                ),
              );
            }).toList();

            // Add farmer current location marker
            markers.add(
              Marker(
                point: center,
                width: 50,
                height: 50,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.blue,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );

            // 4. Render stack with map and floating nearest breeder card
            return Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.palahi',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Floating Highlight Card for Nearest Breeder
                if (nearestBreeder != null)
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
                              child: const Icon(Icons.star, color: Colors.amber, size: 28),
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
                                _showBreederBottomSheet(context, ref, nearestBreeder!, allPigs);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
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
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading breeders: $err')),
        );
      })(),
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
                    onPressed: () async {
                      Navigator.pop(context);
                      final currentUser = ref.read(authRepositoryProvider).currentUser;
                      final profile = ref.read(currentUserProfileProvider).value;
                      if (currentUser != null && profile != null) {
                        final farmerName = profile['name'] as String? ?? 'Farmer';
                        final roomId = await ref.read(chatRepositoryProvider).getOrCreateChatRoom(
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
                      }
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
                      } else if (context.mounted) {
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
