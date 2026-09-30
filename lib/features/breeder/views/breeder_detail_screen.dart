import 'package:palahi/features/profile/viewmodels/own_photo_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/breeder_repository.dart';
import '../repositories/breeding_request_repository.dart';
import '../repositories/review_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../communication/repositories/chat_repository.dart';
import '../../communication/views/chat_room_screen.dart';
import '../../map/repositories/location_service.dart';
import 'widgets/booking_sheet.dart';
import 'widgets/breeder_stud_pigs_grid.dart';
import '../../../core/constants/colors.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

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
          final breederList = breeders.where((b) => b.id == breederId).toList();
          if (breederList.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Breeder Details'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Breeder details not found.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The requested breeder may have been removed or is unavailable.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final breeder = breederList.first;
          final rating = ref.watch(breederRatingProvider(breeder.id));

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
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              color: Colors.green.shade50,
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              breeder.location.isNotEmpty
                                  ? breeder.location
                                  : 'No address provided',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => context.push('/reviews/${breeder.id}'),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.count > 0
                                  ? rating.average.toStringAsFixed(1)
                                  : 'New',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              ' (${rating.count} Reviews)',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.primary),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Services Offered: ${breeder.services.join(', ')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Only the breeder can read their own bookings (the
                      // rules deny this query for anyone else), so for
                      // farmers it always came back empty and showed 0s.
                      if (ref.watch(authRepositoryProvider).currentUser?.uid ==
                          breederId)
                        ref
                            .watch(
                              completedRequestsForBreederProvider(breederId),
                            )
                            .when(
                              data: (bookings) {
                                final totalCompleted = bookings.length;
                                final manualBreedings = bookings
                                    .where(
                                      (b) =>
                                          b.breedingType == 'Manual Breeding',
                                    )
                                    .length;
                                final aiBreedings = bookings
                                    .where(
                                      (b) => b.breedingType.startsWith(
                                        'Artificial',
                                      ),
                                    )
                                    .length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Breeding Experience & History',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildStatCard(
                                          'Completed',
                                          '$totalCompleted',
                                          Icons.task_alt,
                                          Colors.green,
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatCard(
                                          'Manual',
                                          '$manualBreedings',
                                          Icons.pets,
                                          Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatCard(
                                          'AI',
                                          '$aiBreedings',
                                          Icons.science,
                                          Colors.blue,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                              loading: () =>
                                  const Center(child: PigLoader(size: 36)),
                              error: (err, _) => const SizedBox(),
                            ),
                      const SizedBox(height: 24),
                      ref
                          .watch(breederReviewsProvider(breederId))
                          .when(
                            data: (reviews) {
                              if (reviews.isEmpty) return const SizedBox();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Recent Customer Feedback',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          '/reviews/${breeder.id}',
                                        ),
                                        child: const Text('View All'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...reviews
                                      .take(3)
                                      .map(
                                        (r) => Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      r.farmerName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Row(
                                                      children: List.generate(
                                                        5,
                                                        (index) => Icon(
                                                          Icons.star,
                                                          size: 14,
                                                          color:
                                                              index < r.rating
                                                              ? Colors.amber
                                                              : Colors
                                                                    .grey
                                                                    .shade300,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                if (r.review.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    r.review,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (err, _) => const SizedBox(),
                          ),
                      const SizedBox(height: 32),
                      Text(
                        'Available Stud Pigs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      BreederStudPigsGrid(
                        breederId: breederId,
                        availableDates: breeder.availableDates,
                        onPigSelected: (pig) {
                          final role =
                              userProfileAsync.value?['role'] as String? ??
                              'farmer';
                          if (role != 'farmer') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Only farmers can book stud pigs.',
                                ),
                              ),
                            );
                            return;
                          }

                          final farmerName =
                              userProfileAsync.value?['name'] as String? ??
                              'Farmer';

                          if (!pig.isAvailable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This stud pig is not available for '
                                  'breeding right now.',
                                ),
                              ),
                            );
                            return;
                          }
                          showBookingSheet(
                            context,
                            breeder: breeder,
                            pig: pig,
                            farmerName: farmerName,
                          );
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
        loading: () => const Center(child: PigLoader()),
        error: (error, stack) => Center(child: Text(friendlyError(error))),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final currentUser = ref
                        .read(authRepositoryProvider)
                        .currentUser;
                    final profile = ref.read(currentUserProfileProvider).value;
                    final role = profile != null
                        ? profile['role'] as String? ?? 'farmer'
                        : 'farmer';
                    final breeders = breedersAsyncValue.value;

                    if (currentUser == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please log in to send a message.'),
                          ),
                        );
                      }
                      return;
                    }

                    if (breeders == null || breeders.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Breeder data is still loading. Please try again.',
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
                            content: Text('Only farmers can message breeders.'),
                          ),
                        );
                      }
                      return;
                    }

                    final farmerName = profile != null
                        ? profile['name'] as String? ?? 'Farmer'
                        : currentUser.displayName ?? 'Farmer';

                    // Never fall back to another breeder: that silently
                    // opened a chat with whoever was first in the list.
                    final matches = breeders.where((b) => b.id == breederId);
                    if (matches.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This breeder is no longer available.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    final breeder = matches.first;

                    try {
                      final roomId = await ref
                          .read(chatRepositoryProvider)
                          .getOrCreateChatRoom(
                            farmerId: currentUser.uid,
                            farmerName: farmerName,
                            breederId: breeder.id,
                            breederName: breeder.farmName,
                            farmerImageUrl: ref.read(ownPhotoUrlProvider),
                            breederImageUrl: breeder.imageUrl,
                          );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomScreen(
                              roomId: roomId,
                              otherParticipantName: breeder.farmName,
                              otherParticipantImageUrl: breeder.imageUrl,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Message failed: ${friendlyError(e)}',
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
                    final breeders = breedersAsyncValue.value;
                    if (breeders == null || breeders.isEmpty) {
                      return;
                    }

                    // Never fall back to another breeder: that silently gave
                    // directions to whoever was first in the list.
                    final matches = breeders.where((b) => b.id == breederId);
                    if (matches.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This breeder is no longer available.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    final breeder = matches.first;

                    if (breeder.latitude == 0.0 && breeder.longitude == 0.0) {
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

                    final uri = Uri.parse(
                      origin != null
                          ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=${breeder.latitude},${breeder.longitude}'
                          : 'https://www.google.com/maps/search/?api=1&query=${breeder.latitude},${breeder.longitude}',
                    );

                    final launched = await launchUrl(
                      uri,
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
                  child: const Text('Directions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
