import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/stud_pig_repository.dart';
import '../../domain/models/stud_pig_model.dart';
import '../../../../core/constants/colors.dart';

class BreederStudPigsGrid extends ConsumerWidget {
  final String breederId;
  final void Function(StudPigModel) onPigSelected;

  const BreederStudPigsGrid({
    super.key,
    required this.breederId,
    required this.onPigSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pigsAsyncValue = ref.watch(breederStudPigsProvider(breederId));

    return pigsAsyncValue.when(
      data: (pigs) {
        if (pigs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No stud pigs listed yet.'),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: pigs.length,
          itemBuilder: (context, index) {
            final pig = pigs[index];
            return InkWell(
              onTap: () => onPigSelected(pig),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: pig.imageUrl.isNotEmpty
                              ? pig.imageUrl
                              : 'https://images.unsplash.com/photo-1596700813735-a6a7206141cd?auto=format&fit=crop&w=300&q=80',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade200, child: const Icon(Icons.error)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pig.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pig.breed} • ${pig.ageMonths} mo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₱${pig.price.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                              ),
                              if (pig.isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Available', style: TextStyle(color: Colors.green, fontSize: 10)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Booked', style: TextStyle(color: Colors.red, fontSize: 10)),
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Error loading pigs: $error'),
    );
  }
}
