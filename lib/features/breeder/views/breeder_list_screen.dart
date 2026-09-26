import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/views/widgets/breeder_card.dart';
import 'package:palahi/core/utils/error_messages.dart';

class BreederListScreen extends ConsumerStatefulWidget {
  const BreederListScreen({super.key});

  @override
  ConsumerState<BreederListScreen> createState() => _BreederListScreenState();
}

class _BreederListScreenState extends ConsumerState<BreederListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breedersAsyncValue = ref.watch(breedersStreamProvider);

    // No AppBar here: this is a tab inside HomeScreen, whose Scaffold already
    // shows one — a second stacked a duplicate bar on top.
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search breeder...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          // List of Breeders
          Expanded(
            child: breedersAsyncValue.when(
              data: (allBreeders) {
                final query = _searchController.text.trim().toLowerCase();
                final breeders = query.isEmpty
                    ? allBreeders
                    : allBreeders
                          .where(
                            (b) =>
                                b.farmName.toLowerCase().contains(query) ||
                                b.location.toLowerCase().contains(query),
                          )
                          .toList();
                if (breeders.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? 'No breeders found.'
                          : 'No breeders match "$query".',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: breeders.length,
                  itemBuilder: (context, index) {
                    final breeder = breeders[index];
                    return BreederCard(
                      breeder: breeder,
                      onTap: () {
                        context.push('/breeder/${breeder.id}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text(friendlyError(error))),
            ),
          ),
        ],
      ),
    );
  }
}
