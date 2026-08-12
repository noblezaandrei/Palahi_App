class ReviewModel {
  final String id;
  final String bookingId;
  final String breederId;
  final String farmerId;
  final String farmerName;
  final double rating; // Breeder rating
  final String review; // Breeder review text
  final String studPigId;
  final String studPigName;
  final double studPigRating;
  final String studPigReview;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.breederId,
    required this.farmerId,
    required this.farmerName,
    required this.rating,
    required this.review,
    this.studPigId = '',
    this.studPigName = '',
    this.studPigRating = 5.0,
    this.studPigReview = '',
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ReviewModel(
      id: documentId,
      bookingId: json['bookingId'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      farmerId: json['farmerId'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      review: json['review'] as String? ?? json['comment'] as String? ?? '',
      studPigId: json['studPigId'] as String? ?? '',
      studPigName: json['studPigName'] as String? ?? '',
      studPigRating: (json['studPigRating'] as num?)?.toDouble() ?? 5.0,
      studPigReview: json['studPigReview'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['createdAt'].millisecondsSinceEpoch,
            )
          : json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['timestamp'].millisecondsSinceEpoch,
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'breederId': breederId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'rating': rating,
      'review': review,
      'studPigId': studPigId,
      'studPigName': studPigName,
      'studPigRating': studPigRating,
      'studPigReview': studPigReview,
      'createdAt': createdAt,
    };
  }
}
