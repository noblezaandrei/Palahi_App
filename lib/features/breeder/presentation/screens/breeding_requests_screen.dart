import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/breeding_request_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

class BreedingRequestsScreen extends ConsumerWidget {
  const BreedingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    // Assuming we have a way to know if user is a breeder.
    // For simplicity, we can fetch breeder requests if we can. 
    // Ideally, we'd check the user role from UserModel.
    // Let's assume this screen is primarily for Breeders to manage incoming requests for now.
    final requestsAsyncValue = ref.watch(breederRequestsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Breeding Requests'),
      ),
      body: requestsAsyncValue.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No breeding requests found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pig: ${request.studPigName}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          _buildStatusChip(request.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Farmer ID: ${request.farmerId}', style: const TextStyle(color: Colors.grey)), // Replace with actual farmer name in real app
                      const SizedBox(height: 8),
                      if (request.message.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Message: "${request.message}"'),
                        ),
                      if (request.status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ref.read(breedingRequestRepositoryProvider).updateRequestStatus(request.id, 'rejected');
                                },
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  ref.read(breedingRequestRepositoryProvider).updateRequestStatus(request.id, 'approved');
                                },
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
