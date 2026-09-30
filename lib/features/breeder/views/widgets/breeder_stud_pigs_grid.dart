import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../repositories/stud_pig_repository.dart';
import '../../models/stud_pig_model.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'pig_availability.dart';
import '../../../../core/widgets/pig_icon.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

class BreederStudPigsGrid extends ConsumerWidget {
  final String breederId;

  /// The breeder's available dates (yyyy-MM-dd). A pig with no free one
  /// left is greyed out and can't be tapped.
  final List<String> availableDates;
  final void Function(StudPigModel) onPigSelected;

  const BreederStudPigsGrid({
    super.key,
    required this.breederId,
    required this.availableDates,
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
            childAspectRatio: 0.68,
          ),
          itemCount: pigs.length,
          itemBuilder: (context, index) {
            final pig = pigs[index];
            return PigAvailabilityBuilder(
              pig: pig,
              availableDates: availableDates,
              builder: (context, unavailableLabel) =>
                  _buildCard(context, pig, unavailableLabel),
            );
          },
        );
      },
      loading: () => const Center(child: PigLoader()),
      error: (error, stack) =>
          Text('Error loading pigs: ${friendlyError(error)}'),
    );
  }

  Widget _buildCard(
    BuildContext context,
    StudPigModel pig,
    String? unavailableLabel,
  ) {
    final bookable = unavailableLabel == null;
    return InkWell(
      onTap: bookable ? () => onPigSelected(pig) : null,
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
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    // No stock photo for pigs without one — it would look
                    // like the breeder's actual pig.
                    child: pig.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pig.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget: (context, url, error) =>
                                const PigPlaceholder(),
                          )
                        : const PigPlaceholder(),
                  ),
                  if (pig.imageUrl.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ViewFullImageButton(imageUrl: pig.imageUrl),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pig.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pig.breed} • ${pig.ageMonths} mo',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  if (pig.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pig.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible so a long price can't push the
                      // badge off a narrow card.
                      Flexible(
                        child: Text(
                          '₱${pig.price.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                      if (bookable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(color: Colors.green, fontSize: 10),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            unavailableLabel,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 10,
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
    );
  }
}
