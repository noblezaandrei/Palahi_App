import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/breeding_request_repository.dart';
import '../../data/review_repository.dart';
import '../../domain/models/review_model.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

class BreederHistoryScreen extends ConsumerStatefulWidget {
  const BreederHistoryScreen({super.key});

  @override
  ConsumerState<BreederHistoryScreen> createState() => _BreederHistoryScreenState();
}

class _BreederHistoryScreenState extends ConsumerState<BreederHistoryScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final historyAsync = ref.watch(completedRequestsForBreederProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeding History'),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter by:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Manual Breeding', 'Artificial Insemination (AI)'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: historyAsync.when(
              data: (bookings) {
                // Filter client side
                final filteredBookings = bookings.where((b) {
                  if (_selectedFilter == 'All') return true;
                  if (_selectedFilter == 'Manual Breeding') {
                    return b.breedingType == 'Manual Breeding';
                  }
                  // AI
                  return b.breedingType.startsWith('Artificial');
                }).toList();

                if (filteredBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No completed appointments found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pig Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: booking.studPigImageUrl.isNotEmpty
                                      ? Image.network(
                                          booking.studPigImageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 40),
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          width: 60,
                                          height: 60,
                                          child: const Icon(Icons.pets, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.studPigName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Farmer: ${booking.farmerName}',
                                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Type: ${booking.breedingType}',
                                        style: const TextStyle(color: AppColors.primary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking.bookingDate,
                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking.bookingTime,
                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Review and Rating Section
                            FutureBuilder<ReviewModel?>(
                              future: ref.read(reviewRepositoryProvider).getReviewForBooking(booking.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const LinearProgressIndicator(minHeight: 2);
                                }
                                
                                final review = snapshot.data;
                                if (review == null) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'No review received yet.',
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                                    ),
                                  );
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50.withAlpha(100),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade200, width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Feedback Received:',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
                                          ),
                                          Row(
                                            children: List.generate(5, (starIdx) => Icon(
                                              Icons.star,
                                              size: 14,
                                              color: starIdx < review.rating ? Colors.amber : Colors.grey.shade300,
                                            )),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '"${review.review}"',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          'Reviewed on: ${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading history: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
