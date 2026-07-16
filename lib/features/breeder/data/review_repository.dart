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
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addReview(ReviewModel review) async {
    await _firestore.collection('reviews').add(review.toJson());
  }
}
