import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(FirebaseFirestore.instance);
});

final breederReviewsProvider = StreamProvider.family<List<ReviewModel>, String>(
  (ref, breederId) {
    return ref.watch(reviewRepositoryProvider).getReviewsForBreeder(breederId);
  },
);

final farmerReviewsProvider = StreamProvider.family<List<ReviewModel>, String>(
  (ref, farmerId) {
    return ref.watch(reviewRepositoryProvider).getReviewsForFarmer(farmerId);
  },
);

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository(this._firestore);

  Stream<List<ReviewModel>> getReviewsForBreeder(String breederId) {
    return _firestore
        .collection('reviews')
        .where('breederId', isEqualTo: breederId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReviewModel.fromJson(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<ReviewModel>> getReviewsForFarmer(String farmerId) {
    return _firestore
        .collection('reviews')
        .where('farmerId', isEqualTo: farmerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReviewModel.fromJson(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
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
      throw Exception(
        'A review has already been submitted for this breeding appointment.',
      );
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
      await breederDocRef.update({'rating': average, 'reviewCount': count});
    }

    // 5. Re-calculate and update stud pig average rating and review counts
    if (review.studPigId.isNotEmpty) {
      final pigReviewsSnapshot = await _firestore
          .collection('reviews')
          .where('studPigId', isEqualTo: review.studPigId)
          .get();

      double totalPigRating = 0.0;
      final int pigCount = pigReviewsSnapshot.docs.length;

      for (var doc in pigReviewsSnapshot.docs) {
        final data = doc.data();
        final pigRating = (data['studPigRating'] ?? data['rating'] ?? 5.0) as num;
        totalPigRating += pigRating.toDouble();
      }

      final double pigAverage = pigCount > 0 ? totalPigRating / pigCount : 5.0;

      final pigDocRef = _firestore.collection('stud_pigs').doc(review.studPigId);
      final pigDoc = await pigDocRef.get();
      if (pigDoc.exists) {
        await pigDocRef.update({
          'rating': pigAverage,
          'reviewCount': pigCount,
        });
      }
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
