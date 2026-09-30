import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/widgets/gradient_header.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/favorite_repository.dart';
import 'package:palahi/features/breeder/views/widgets/breeder_card.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final role = profile != null
        ? profile['role'] as String? ?? 'farmer'
        : 'farmer';

    // No AppBar: this is a HomeScreen tab, which already shows one.
    if (role != 'farmer') {
      return const Scaffold(
        body: Center(child: Text('Favorites are available to farmers only.')),
      );
    }
    final favoritesAsyncValue = ref.watch(userFavoritesProvider);
    final breedersAsyncValue = ref.watch(breedersStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Saved Breeders',
            subtitle: 'Your go-to farms, one tap away',
            stats: [
              (
                value: '${favoritesAsyncValue.value?.length ?? 0}',
                label: 'Saved',
              ),
            ],
          ),
          Expanded(
            child: favoritesAsyncValue.when(
              loading: () => const Center(child: PigLoader()),
              error: (e, s) => Center(child: Text(friendlyError(e))),
              data: (favoriteIds) {
                if (favoriteIds.isEmpty) return const _NoFavorites();

                return breedersAsyncValue.when(
                  loading: () => const Center(child: PigLoader()),
                  error: (e, s) => Center(child: Text(friendlyError(e))),
                  data: (allBreeders) {
                    final favoriteBreeders = allBreeders
                        .where((b) => favoriteIds.contains(b.id))
                        .toList();
                    if (favoriteBreeders.isEmpty) return const _NoFavorites();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: favoriteBreeders.length,
                      itemBuilder: (context, index) {
                        final breeder = favoriteBreeders[index];
                        return FadeSlideIn(
                          index: index,
                          child: BreederCard(
                            breeder: breeder,
                            onTap: () => context.push('/breeder/${breeder.id}'),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFavorites extends StatelessWidget {
  const _NoFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.primaryLight,
            ),
            SizedBox(height: 12),
            Text(
              'No saved breeders yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Tap the bookmark on a breeder to keep them here for quick '
              'booking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
