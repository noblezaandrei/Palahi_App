import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(FirebaseFirestore.instance);
});

final breederReviewsProvider = StreamProvider.family<List<ReviewModel>, String>((ref, breederId) {
  return ref.watch(reviewRepositoryProvider).getReviewsForBreeder(breederId);
});

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository(this._firestore);

  Stream<List<ReviewModel>> getReviewsForBreeder(String breederId) {
    return _firestore
        .collection('reviews')
        .where('breederId', isEqualTo: breederId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  /// Adds a review for a booking. Prevents duplicate reviews and updates breeder ratings.
  Future<void> addReview(ReviewModel review) async {
    // 1. Prevent duplicate reviews for the same booking
    final duplicateQuery = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: review.bookingId)
        .get();

    if (duplicateQuery.docs.isNotEmpty) {
      throw Exception('A review has already been submitted for this breeding appointment.');
    }

    // 2. Add new review
    await _firestore.collection('reviews').add(review.toJson());

    // 3. Re-calculate breeder average rating and review counts
    final breederId = review.breederId;
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('breederId', isEqualTo: breederId)
        .get();

    double totalRating = 0.0;
    final int count = reviewsSnapshot.docs.length;

    for (var doc in reviewsSnapshot.docs) {
      totalRating += (doc.data()['rating'] as num).toDouble();
    }

    final double average = count > 0 ? totalRating / count : 5.0;

    // 4. Update the breeder profile record
    final breederDocRef = _firestore.collection('breeders').doc(breederId);
    final breederDoc = await breederDocRef.get();

    if (breederDoc.exists) {
      await breederDocRef.update({
        'rating': average,
        'reviewCount': count,
      });
    }
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
