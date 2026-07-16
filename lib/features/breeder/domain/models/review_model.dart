class ReviewModel {
  final String id;
  final String breederId;
  final String farmerId;
  final String farmerName;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.breederId,
    required this.farmerId,
    required this.farmerName,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ReviewModel(
      id: documentId,
      breederId: json['breederId'] as String? ?? '',
      farmerId: json['farmerId'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'].millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breederId': breederId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}
