import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/review_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/colors.dart';

class ReviewsScreen extends ConsumerWidget {
  final String breederId;
  const ReviewsScreen({super.key, required this.breederId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final userRole = profileAsync.value?['role'] ?? 'farmer';

    // If the logged-in user is a farmer viewing their own profile reviews, query by farmerId
    final isFarmerViewingOwn = currentUser != null &&
        currentUser.uid == breederId &&
        userRole == 'farmer';

    final reviewsAsyncValue = isFarmerViewingOwn
        ? ref.watch(farmerReviewsProvider(breederId))
        : ref.watch(breederReviewsProvider(breederId));

    final title = isFarmerViewingOwn ? 'My Submitted Reviews' : 'Reviews & Ratings';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: reviewsAsyncValue.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFarmerViewingOwn
                          ? 'You have not submitted any reviews yet.'
                          : 'No reviews received yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFarmerViewingOwn
                          ? 'Reviews can be submitted after completing a breeding appointment.'
                          : 'Reviews submitted by farmers will appear here.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                              isFarmerViewingOwn
                                  ? 'Stud Pig: ${review.studPigName.isNotEmpty ? review.studPigName : "Stud Pig"}'
                                  : review.farmerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < review.rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted on: ${review.createdAt.month}/${review.createdAt.day}/${review.createdAt.year}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const Divider(height: 20),
                      if (review.review.isNotEmpty) ...[
                        Text(
                          'Breeder Feedback:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.review,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                      if (review.studPigReview.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Stud Pig Performance (${review.studPigRating}★):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.studPigReview,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                          ),
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
}
