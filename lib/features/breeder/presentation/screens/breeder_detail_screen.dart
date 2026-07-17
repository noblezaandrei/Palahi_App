import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/breeder_repository.dart';
import '../../domain/models/breeder_model.dart';
import '../../domain/models/stud_pig_model.dart';
import '../../domain/models/breeding_request_model.dart';
import '../../data/breeding_request_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../communication/data/chat_repository.dart';
import '../../../communication/presentation/screens/chat_room_screen.dart';
import '../widgets/breeder_stud_pigs_grid.dart';
import '../../../../core/constants/colors.dart';

class BreederDetailScreen extends ConsumerWidget {
  final String breederId;

  const BreederDetailScreen({super.key, required this.breederId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breedersAsyncValue = ref.watch(breedersStreamProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      body: breedersAsyncValue.when(
        data: (breeders) {
          final breeder = breeders.firstWhere(
            (b) => b.id == breederId,
            orElse: () => throw Exception('Breeder not found'),
          );

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      breeder.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: breeder.imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.store, size: 80, color: Colors.white),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(100),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              breeder.farmName,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              breeder.location.isNotEmpty ? breeder.location : 'No address provided',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => context.push('/reviews/${breeder.id}'),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              breeder.rating.toString(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              ' (${breeder.reviewCount} Reviews)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Services Offered: ${breeder.services.join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        breeder.about.isNotEmpty
                            ? breeder.about
                            : 'No about information available for this breeder.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Available Stud Pigs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      BreederStudPigsGrid(
                        breederId: breederId,
                        onPigSelected: (pig) {
                          final farmerName = userProfileAsync.value?['name'] as String? ?? 'Farmer';
                          _showRequestBreedingDialog(context, ref, breeder, pig, farmerName);
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final currentUser = ref.read(authRepositoryProvider).currentUser;
                    final profile = ref.read(currentUserProfileProvider).value;
                    final breeders = breedersAsyncValue.value;
                    
                    if (currentUser != null && profile != null && breeders != null) {
                      final farmerName = profile['name'] as String? ?? 'Farmer';
                      final breeder = breeders.firstWhere(
                        (b) => b.id == breederId,
                        orElse: () => breeders.first,
                      );
                      
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
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Open map coordinates using url_launcher
                    final breeders = breedersAsyncValue.value;
                    if (breeders != null && breeders.isNotEmpty) {
                      final breeder = breeders.firstWhere(
                        (b) => b.id == breederId,
                        orElse: () => breeders.first,
                      );
                      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${breeder.latitude},${breeder.longitude}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch maps application')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Directions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestBreedingDialog(
    BuildContext context,
    WidgetRef ref,
    BreederModel breeder,
    StudPigModel pig,
    String farmerName,
  ) {
    if (!pig.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This stud pig is currently booked or unavailable.')),
      );
      return;
    }

    final messageController = TextEditingController();
    
    // Determine available services options based on breeder services and pig services
    List<String> availableServices = [];
    if (pig.serviceType == 'Both') {
      availableServices = List<String>.from(breeder.services);
    } else {
      availableServices = [pig.serviceType];
    }
    
    // Fallback if empty
    if (availableServices.isEmpty) {
      availableServices = ['Natural Breeding', 'Artificial Insemination'];
    }

    String selectedService = availableServices.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Request ${pig.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stud Fee: ₱${pig.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Select Breeding Service:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...availableServices.map((service) => RadioListTile<String>(
                    title: Text(service),
                    value: service,
                    groupValue: selectedService,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedService = val;
                        });
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  )),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message to Breeder',
                  hintText: 'E.g., I would like to visit tomorrow...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;

                final request = BreedingRequestModel(
                  id: '',
                  farmerId: user.uid,
                  farmerName: farmerName,
                  breederId: breeder.id,
                  breederName: breeder.farmName,
                  studPigId: pig.id,
                  studPigName: pig.name,
                  studPigImageUrl: pig.imageUrl,
                  status: 'pending',
                  serviceType: selectedService,
                  message: messageController.text.trim(),
                  timestamp: DateTime.now(),
                );

                await ref.read(breedingRequestRepositoryProvider).sendRequest(request);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Breeding request sent!')),
                  );
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}
