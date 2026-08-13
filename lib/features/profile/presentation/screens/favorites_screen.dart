import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/features/breeder/data/breeder_repository.dart';
import 'package:palahi/features/breeder/data/favorite_repository.dart';
import 'package:palahi/features/breeder/presentation/widgets/breeder_card.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final role = profile != null
        ? profile['role'] as String? ?? 'farmer'
        : 'farmer';

    if (role != 'farmer') {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Breeders')),
        body: const Center(
          child: Text('Favorites are available to farmers only.'),
        ),
      );
    }
    final favoritesAsyncValue = ref.watch(userFavoritesProvider);
    final breedersAsyncValue = ref.watch(breedersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Breeders')),
      body: favoritesAsyncValue.when(
        data: (favoriteIds) {
          if (favoriteIds.isEmpty) {
            return const Center(child: Text('No saved breeders yet.'));
          }

          return breedersAsyncValue.when(
            data: (allBreeders) {
              final favoriteBreeders = allBreeders
                  .where((b) => favoriteIds.contains(b.id))
                  .toList();

              if (favoriteBreeders.isEmpty) {
                return const Center(
                  child: Text('Saved breeders no longer exist.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteBreeders.length,
                itemBuilder: (context, index) {
                  final breeder = favoriteBreeders[index];
                  return BreederCard(
                    breeder: breeder,
                    onTap: () => context.push('/breeder/${breeder.id}'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
