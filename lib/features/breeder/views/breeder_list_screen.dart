import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/widgets/gradient_header.dart';
import 'package:palahi/core/widgets/pig_icon.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/favorite_repository.dart';
import 'package:palahi/features/breeder/views/widgets/breeder_card.dart';
import 'package:palahi/features/map/repositories/location_service.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

enum _BreederSort { nearest, name }

class BreederListScreen extends ConsumerStatefulWidget {
  const BreederListScreen({super.key});

  @override
  ConsumerState<BreederListScreen> createState() => _BreederListScreenState();
}

class _BreederListScreenState extends ConsumerState<BreederListScreen> {
  final TextEditingController _searchController = TextEditingController();
  _BreederSort _sort = _BreederSort.nearest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breedersAsyncValue = ref.watch(breedersStreamProvider);
    final origin = ref.watch(distanceOriginProvider);
    final savedCount = ref.watch(userFavoritesProvider).value?.length ?? 0;

    // No AppBar here: this is a tab inside HomeScreen, whose Scaffold already
    // shows one — a second stacked a duplicate bar on top.
    return Scaffold(
      body: breedersAsyncValue.when(
        loading: () => const Center(child: PigLoader()),
        error: (error, stack) => Center(child: Text(friendlyError(error))),
        data: (allBreeders) {
          final distances = {
            for (final b in allBreeders) b.id: breederDistanceKm(origin, b),
          };
          final nearest = distances.values.whereType<double>().fold<double?>(
            null,
            (min, d) => min == null || d < min ? d : min,
          );

          final query = _searchController.text.trim().toLowerCase();
          final breeders =
              (query.isEmpty
                    ? [...allBreeders]
                    : allBreeders
                          .where(
                            (b) =>
                                b.farmName.toLowerCase().contains(query) ||
                                b.location.toLowerCase().contains(query),
                          )
                          .toList())
                ..sort((a, b) {
                  if (_sort == _BreederSort.nearest) {
                    // Farms with no known distance go last.
                    final da = distances[a.id] ?? double.infinity;
                    final db = distances[b.id] ?? double.infinity;
                    final byDistance = da.compareTo(db);
                    if (byDistance != 0) return byDistance;
                  }
                  return a.farmName.toLowerCase().compareTo(
                    b.farmName.toLowerCase(),
                  );
                });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  title: 'Find a Breeder',
                  subtitle: 'Trusted stud pig farms around Camalig',
                  stats: [
                    (value: '${allBreeders.length}', label: 'Farms'),
                    (value: '$savedCount', label: 'Saved'),
                    (
                      value: nearest == null
                          ? '—'
                          : '${nearest.toStringAsFixed(1)} km',
                      label: 'Nearest',
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by farm name or location',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(_searchController.clear),
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${breeders.length} '
                        '${breeders.length == 1 ? 'farm' : 'farms'}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Nearest'),
                        selected: _sort == _BreederSort.nearest,
                        onSelected: (_) =>
                            setState(() => _sort = _BreederSort.nearest),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('A–Z'),
                        selected: _sort == _BreederSort.name,
                        onSelected: (_) =>
                            setState(() => _sort = _BreederSort.name),
                      ),
                    ],
                  ),
                ),
              ),
              if (breeders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ListEmptyState(
                    title: query.isEmpty
                        ? 'No breeders yet'
                        : 'No breeders match "$query"',
                    message: query.isEmpty
                        ? 'Breeders will show up here once they join.'
                        : 'Try a different farm name or location.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList.builder(
                    itemCount: breeders.length,
                    itemBuilder: (context, index) {
                      final breeder = breeders[index];
                      return FadeSlideIn(
                        index: index,
                        child: BreederCard(
                          breeder: breeder,
                          onTap: () => context.push('/breeder/${breeder.id}'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The friendly "nothing here" message for the farmer's breeder lists.
class _ListEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _ListEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PigIcon(size: 72),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
