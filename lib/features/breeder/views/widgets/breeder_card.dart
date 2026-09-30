import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/breeder/repositories/favorite_repository.dart';
import 'package:palahi/features/breeder/repositories/review_repository.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/location_utils.dart';
import 'package:palahi/features/map/repositories/location_service.dart';

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

    // From the farmer's pinned farm, like the Map tab, so both agree.
    final km = breederDistanceKm(ref.watch(distanceOriginProvider), breeder);
    final distanceText = km == null ? '' : '${km.toStringAsFixed(1)} km away';

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
                // No stock photo for farms without one — it would look like
                // the breeder's actual farm.
                child: breeder.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: breeder.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) =>
                            const _FarmPlaceholder(),
                      )
                    : const _FarmPlaceholder(),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            breeder.location.isNotEmpty
                                ? breeder.location
                                : 'Location not set',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                        if (distanceText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              distanceText,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

/// Straight-line km from [origin] to [breeder]'s farm, or null if either
/// isn't known.
double? breederDistanceKm(
  ({double lat, double lng})? origin,
  BreederModel breeder,
) {
  if (origin == null || (breeder.latitude == 0 && breeder.longitude == 0)) {
    return null;
  }
  return LocationUtils.getDistanceKm(
    origin.lat,
    origin.lng,
    breeder.latitude,
    breeder.longitude,
  );
}

class _FarmPlaceholder extends StatelessWidget {
  const _FarmPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.primaryBackground,
      child: const Icon(Icons.storefront, color: AppColors.primary, size: 36),
    );
  }
}
