import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/breeding_request_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

class BreedingRequestsScreen extends ConsumerWidget {
  const BreedingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final profileAsync = ref.watch(currentUserProfileProvider);
    final userRole = profileAsync.value?['role'] ?? 'farmer';
    final isFarmer = userRole == 'farmer';
    final greetingName =
        (profileAsync.value?['name'] as String?)?.trim().isNotEmpty == true
        ? profileAsync.value!['name'] as String
        : (isFarmer ? 'Farmer' : 'Breeder');

    final requestsAsyncValue = isFarmer
        ? ref.watch(farmerRequestsProvider(user.uid))
        : ref.watch(breederRequestsProvider(user.uid));

    final title = isFarmer
        ? 'My Breeding Requests'
        : 'Incoming Breeding Requests';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Hello, $greetingName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: requestsAsyncValue.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFarmer
                                ? 'You have no active breeding requests.'
                                : 'No incoming breeding requests.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFarmer
                                ? 'Browse stud pigs and send booking requests to breeders.'
                                : 'When farmers request breeding services, they will appear here.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pig: ${request.studPigName}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusChip(request.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (request.studPigImageUrl.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  request.studPigImageUrl,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _buildParticipantTile(
                                    label: 'Farmer',
                                    name: request.farmerName,
                                    imageUrl: request.farmerImageUrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildParticipantTile(
                                    label: 'Breeder',
                                    name: request.breederName,
                                    imageUrl: request.breederImageUrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Breeding Type: ${request.breedingType}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Schedule: ${request.bookingDate} at ${request.bookingTime}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Booked on: ${request.createdAt.month}/${request.createdAt.day}/${request.createdAt.year}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (request.notes.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Notes: "${request.notes}"',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (request.status == 'pending') ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (!isFarmer) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'rejected',
                                              );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'accepted',
                                              );
                                        },
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'cancelled',
                                              );
                                        },
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancel Request'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ] else if (request.status == 'accepted') ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (isFarmer) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Mark Breeding Completed',
                                              ),
                                              content: const Text(
                                                'Are you sure the breeding service is done? This will notify the breeder for payment confirmation.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Confirm Done Breeding',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await ref
                                                .read(
                                                  breedingRequestRepositoryProvider,
                                                )
                                                .updateRequestStatus(
                                                  request.id,
                                                  'done_breeding',
                                                );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text('Done Breeding'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(
                                                breedingRequestRepositoryProvider,
                                              )
                                              .updateRequestStatus(
                                                request.id,
                                                'cancelled',
                                              );
                                        },
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancel Booking'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Center(
                                        child: Text(
                                          'Awaiting farmer completion confirmation...',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ] else if (request.status == 'done_breeding') ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (!isFarmer) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Confirm Receive Payment',
                                              ),
                                              content: const Text(
                                                'Please confirm that you have received the CASH payment from the farmer for this breeding service.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Confirm Cash Received',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await ref
                                                .read(
                                                  breedingRequestRepositoryProvider,
                                                )
                                                .updateRequestStatus(
                                                  request.id,
                                                  'completed',
                                                );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                        ),
                                        label: const Text('Receive Payment'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const Expanded(
                                      child: Center(
                                        child: Text(
                                          'Done breeding! Awaiting breeder cash payment confirmation...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile({
    required String label,
    required String name,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.black54),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'done_breeding':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.teal;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'cancelled':
        color = Colors.grey;
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
        status == 'done_breeding' ? 'DONE BREEDING' : status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
