import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palahi/features/breeder/domain/models/breeder_model.dart';
import 'package:palahi/features/breeder/data/favorite_repository.dart';
import 'package:palahi/features/breeder/data/review_repository.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';
import 'package:palahi/features/map/data/location_service.dart';

class BreederCard extends ConsumerWidget {
  final BreederModel breeder;
  final VoidCallback onTap;

  const BreederCard({super.key, required this.breeder, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final role =
        ref.watch(currentUserProfileProvider).value?['role'] as String? ??
        'farmer';
    final favorites = ref.watch(userFavoritesProvider).value ?? [];
    final isFavorite = favorites.contains(breeder.id);

    final rating = ref.watch(breederRatingProvider(breeder.id));

    final locationAsync = ref.watch(currentLocationProvider);
    final distanceText = locationAsync.when(
      data: (pos) {
        final dist = LocationUtils.getDistanceKm(
          pos.latitude,
          pos.longitude,
          breeder.latitude,
          breeder.longitude,
        );
        return '${dist.toStringAsFixed(1)} km away';
      },
      loading: () => 'Calculating...',
      error: (err, stack) => 'Distance N/A',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breeder Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: breeder.imageUrl.isNotEmpty
                      ? breeder.imageUrl
                      : 'https://images.unsplash.com/photo-1604848698030-c434ba08ece1?auto=format&fit=crop&w=300&q=80',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.store, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Breeder Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            breeder.farmName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_border,
                            color: AppColors.primary,
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please log in to manage favorites.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (role != 'farmer') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Only farmers can favorite breeders.',
                                  ),
                                ),
                              );
                              return;
                            }

                            ref
                                .read(favoriteRepositoryProvider)
                                .toggleFavorite(
                                  user.uid,
                                  breeder.id,
                                  isFavorite,
                                );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breeder.location,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.count > 0
                              ? rating.average.toStringAsFixed(1)
                              : 'New',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        if (rating.count > 0)
                          Text(
                            ' (${rating.count})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const Spacer(),
                        Text(
                          distanceText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
