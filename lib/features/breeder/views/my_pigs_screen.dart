import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../repositories/stud_pig_repository.dart';
import 'manage_stud_pig_screen.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/pig_icon.dart';
import '../../../core/widgets/gradient_header.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';
import '../../tracker/models/breeding_record.dart';
import '../../tracker/repositories/breeding_record_repository.dart';

class MyPigsScreen extends ConsumerWidget {
  const MyPigsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final profile = ref.watch(currentUserProfileProvider).value;
    final role = (profile?['role'] as String?)?.toLowerCase() ?? 'breeder';
    final greetingName =
        (profile?['name'] as String?)?.trim().isNotEmpty == true
        ? profile!['name'] as String
        : (role == 'breeder' ? 'Breeder' : 'Farmer');

    final pigsAsyncValue = ref.watch(breederStudPigsProvider(user.uid));
    // What farmers reported after each breeding, for each boar's rate.
    final records =
        ref.watch(breederBreedingRecordsProvider(user.uid)).value?.values ??
        const <BreedingRecord>[];

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Hello, $greetingName',
            subtitle: 'Manage your stud pigs and their listings',
            stats: switch (pigsAsyncValue.value) {
              final pigs? when pigs.isNotEmpty => [
                (value: '${pigs.length}', label: 'Listed'),
                (
                  value: '${pigs.where((p) => p.isAvailable).length}',
                  label: 'Available',
                ),
                (
                  value: '${pigs.where((p) => !p.isAvailable).length}',
                  label: 'Resting',
                ),
              ],
              _ => const [],
            },
          ),
          Expanded(
            child: pigsAsyncValue.when(
              data: (pigs) {
                if (pigs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const PigIcon(size: 96),
                        const SizedBox(height: 16),
                        const Text(
                          'No stud pigs listed yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'List your first boar so farmers nearby\n'
                          'can find and book it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ManageStudPigScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Stud Pig'),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: pigs.length,
                  itemBuilder: (context, index) {
                    final pig = pigs[index];
                    return FadeSlideIn(
                      index: index,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ManageStudPigScreen(existingPig: pig),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
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
                                      child: pig.imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: pig.imageUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              placeholder: (context, url) =>
                                                  const LoadingPulse(),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const PigPlaceholder(),
                                            )
                                          : const PigPlaceholder(iconSize: 56),
                                    ),
                                    if (pig.imageUrl.isNotEmpty)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: ViewFullImageButton(
                                          imageUrl: pig.imageUrl,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pig.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${pig.breed} • ${pig.ageMonths} mo',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
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
                                    const SizedBox(height: 4),
                                    Builder(
                                      builder: (context) {
                                        final rate = conceptionRate(
                                          records,
                                          pig.id,
                                        );
                                        return Text(
                                          '${pig.weight.toStringAsFixed(1)} kg'
                                          '${rate.reported == 0 ? '' : ' · ${rate.conceived}/${rate.reported} conceived'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            pig.price > 0
                                                ? '₱${pig.price.toStringAsFixed(0)}'
                                                : 'Free / Inquire',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pig.isAvailable
                                                ? Colors.green.shade50
                                                : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            pig.isAvailable
                                                ? 'Available'
                                                : 'Not available',
                                            style: TextStyle(
                                              color: pig.isAvailable
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
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
                  },
                );
              },
              loading: () => const Center(child: PigLoader()),
              error: (error, stack) => Center(
                child: Text('Error loading pigs: ${friendlyError(error)}'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManageStudPigScreen(),
            ),
          );
        },
        tooltip: 'Add a stud pig',
        icon: const PigIcon(size: 30, withPlus: true),
        label: const Text('Add Stud Pig'),
      ),
    );
  }
}
