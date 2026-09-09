import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/review_model.dart';
import '../../auth/data/auth_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(FirebaseFirestore.instance);
});

final breederReviewsProvider = StreamProvider.family<List<ReviewModel>, String>(
  (ref, breederId) {
    // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
    // a permission-denied error during logout stays cached empty forever.
    ref.watch(authStateProvider);
    return ref.watch(reviewRepositoryProvider).getReviewsForBreeder(breederId);
  },
);

/// A breeder's rating, computed live from their actual reviews instead of a
/// denormalized field — farmers can't write to a breeder's own document, so
/// there's no reliable way to keep a stored rating field in sync with theirs.
final breederRatingProvider = Provider.family<({double average, int count}), String>(
  (ref, breederId) {
    final reviewsAsync = ref.watch(breederReviewsProvider(breederId));
    return reviewsAsync.maybeWhen(
      data: (reviews) {
        if (reviews.isEmpty) return (average: 0.0, count: 0);
        final total = reviews.fold<double>(0, (acc, r) => acc + r.rating);
        return (average: total / reviews.length, count: reviews.length);
      },
      orElse: () => (average: 0.0, count: 0),
    );
  },
);

final farmerReviewsProvider = StreamProvider.family<List<ReviewModel>, String>((
  ref,
  farmerId,
) {
  ref.watch(authStateProvider);
  return ref.watch(reviewRepositoryProvider).getReviewsForFarmer(farmerId);
});

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository(this._firestore);

  Stream<List<ReviewModel>> getReviewsForBreeder(String breederId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('reviews')
              .where('breederId', isEqualTo: breederId)
              .snapshots()) {
        final list = snapshot.docs
            .map((doc) => ReviewModel.fromJson(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (error) {
      debugPrint('Failed to load breeder reviews: $error');
      yield <ReviewModel>[];
    }
  }

  Stream<List<ReviewModel>> getReviewsForFarmer(String farmerId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('reviews')
              .where('farmerId', isEqualTo: farmerId)
              .snapshots()) {
        final list = snapshot.docs
            .map((doc) => ReviewModel.fromJson(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (error) {
      debugPrint('Failed to load farmer reviews: $error');
      yield <ReviewModel>[];
    }
  }

  /// Adds a review for a booking. Prevents duplicate reviews. Breeder/pig
  /// ratings are derived live from reviews (see breederRatingProvider)
  /// rather than stored, since a farmer has no write access to a breeder's
  /// or pig's own document to keep a denormalized rating field in sync.
  Future<void> addReview(ReviewModel review) async {
    final duplicateQuery = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: review.bookingId)
        .get();

    if (duplicateQuery.docs.isNotEmpty) {
      throw Exception(
        'A review has already been submitted for this breeding appointment.',
      );
    }

    await _firestore.collection('reviews').add(review.toJson());
  }

  /// Checks if a booking has already been reviewed.
  Future<bool> isBookingReviewed(String bookingId) async {
    final query = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Fetches the review submitted for a specific booking.
  Future<ReviewModel?> getReviewForBooking(String bookingId) async {
    final query = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return ReviewModel.fromJson(query.docs.first.data(), query.docs.first.id);
  }
}
