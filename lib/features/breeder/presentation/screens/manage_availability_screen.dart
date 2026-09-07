import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/breeder_repository.dart';
import '../../domain/models/breeder_model.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

String formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ManageAvailabilityScreen extends ConsumerWidget {
  const ManageAvailabilityScreen({super.key});

  Future<void> _addDate(
    BuildContext context,
    WidgetRef ref,
    BreederModel breeder,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      selectableDayPredicate: (date) =>
          !breeder.availableDates.contains(formatDate(date)),
    );
    if (picked == null) return;

    final updated = [...breeder.availableDates, formatDate(picked)]..sort();
    await ref
        .read(breederRepositoryProvider)
        .updateAvailableDates(breeder.id, updated);
  }

  Future<void> _removeDate(
    WidgetRef ref,
    BreederModel breeder,
    String date,
  ) async {
    final updated = breeder.availableDates.where((d) => d != date).toList();
    await ref
        .read(breederRepositoryProvider)
        .updateAvailableDates(breeder.id, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final breedersAsync = ref.watch(breedersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Availability')),
      body: breedersAsync.when(
        data: (breeders) {
          final breeder = breeders.firstWhere(
            (b) => b.id == user.uid,
            orElse: () => BreederModel(
              id: user.uid,
              userId: user.uid,
              farmName: '',
              location: '',
              latitude: 0,
              longitude: 0,
              rating: 0,
              reviewCount: 0,
              imageUrl: '',
              about: '',
              services: const [],
            ),
          );

          final today = formatDate(DateTime.now());
          final upcomingDates =
              breeder.availableDates.where((d) => d.compareTo(today) >= 0)
                  .toList()
                ..sort();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Farmers can only book you on the dates you add here.",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addDate(context, ref, breeder),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Available Date'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Available Dates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: upcomingDates.isEmpty
                      ? Center(
                          child: Text(
                            'No available dates yet.\nAdd one above so farmers can book you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          itemCount: upcomingDates.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final date = upcomingDates[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.event_available,
                                color: AppColors.primary,
                              ),
                              title: Text(date),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _removeDate(ref, breeder, date),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
