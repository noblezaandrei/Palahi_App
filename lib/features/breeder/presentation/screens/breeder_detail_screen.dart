import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/breeder_repository.dart';
import '../../domain/models/breeder_model.dart';
import '../../domain/models/stud_pig_model.dart';
import '../../domain/models/breeding_request_model.dart';
import '../../data/breeding_request_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../widgets/breeder_stud_pigs_grid.dart';
import '../../../../core/constants/colors.dart';

class BreederDetailScreen extends ConsumerWidget {
  final String breederId;

  const BreederDetailScreen({super.key, required this.breederId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breedersAsyncValue = ref.watch(breedersStreamProvider);

    return Scaffold(
      body: breedersAsyncValue.when(
        data: (breeders) {
          final breeder = breeders.firstWhere(
            (b) => b.id == breederId,
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: breeder.imageUrl.isNotEmpty
                            ? breeder.imageUrl
                            : 'https://images.unsplash.com/photo-1604848698030-c434ba08ece1?auto=format&fit=crop&w=300&q=80',
                        fit: BoxFit.cover,
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
                          Text(
                            breeder.location,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                          const Spacer(),
                          const Icon(Icons.directions_car_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '0.0 km away',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                        'Stud Pigs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      BreederStudPigsGrid(
                        breederId: breederId,
                        onPigSelected: (pig) {
                          _showRequestBreedingDialog(context, ref, breeder, pig);
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
                  onPressed: () {
                    context.push('/messages');
                  },
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Directions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestBreedingDialog(BuildContext context, WidgetRef ref, BreederModel breeder, StudPigModel pig) {
    if (!pig.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This stud pig is currently booked or unavailable.')),
      );
      return;
    }

    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request ${pig.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stud Fee: ₱${pig.price.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message to Breeder',
                hintText: 'E.g., I would like to visit tomorrow...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authRepositoryProvider).currentUser;
              if (user == null) return;

              final request = BreedingRequestModel(
                id: '',
                farmerId: user.uid,
                breederId: breeder.id,
                studPigId: pig.id,
                studPigName: pig.name,
                status: 'pending',
                message: messageController.text.trim(),
                timestamp: DateTime.now(),
              );

              await ref.read(breedingRequestRepositoryProvider).sendRequest(request);
              
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Breeding request sent!')),
                );
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}
