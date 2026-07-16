import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/breeder_repository.dart';
import '../widgets/breeder_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search breeder...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
              data: (breeders) {
                if (breeders.isEmpty) {
                  return const Center(child: Text('No breeders found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
