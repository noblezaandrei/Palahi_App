class BreedingRequestModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String breederId;
  final String breederName;
  final String studPigId;
  final String studPigName;
  final String studPigImageUrl;
  final String status; // 'pending', 'accepted', 'rejected', 'completed', 'cancelled'
  final String breedingType; // 'Manual Breeding' or 'Artificial Insemination (AI)'
  final String bookingDate; // 'yyyy-MM-dd'
  final String bookingTime; // e.g. '10:00 AM'
  final String notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  BreedingRequestModel({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.breederId,
    required this.breederName,
    required this.studPigId,
    required this.studPigName,
    required this.studPigImageUrl,
    required this.status,
    required this.breedingType,
    required this.bookingDate,
    required this.bookingTime,
    required this.notes,
    required this.createdAt,
    this.completedAt,
  });

  factory BreedingRequestModel.fromJson(Map<String, dynamic> json, String documentId) {
    return BreedingRequestModel(
      id: documentId,
      farmerId: json['farmerId'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      breederName: json['breederName'] as String? ?? '',
      studPigId: json['studPigId'] as String? ?? '',
      studPigName: json['studPigName'] as String? ?? '',
      studPigImageUrl: json['studPigImageUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      breedingType: json['breedingType'] as String? ?? json['serviceType'] as String? ?? 'Manual Breeding',
      bookingDate: json['bookingDate'] as String? ?? '',
      bookingTime: json['bookingTime'] as String? ?? '',
      notes: json['notes'] as String? ?? json['message'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'].millisecondsSinceEpoch)
          : json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'].millisecondsSinceEpoch)
              : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'].millisecondsSinceEpoch)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'breederId': breederId,
      'breederName': breederName,
      'studPigId': studPigId,
      'studPigName': studPigName,
      'studPigImageUrl': studPigImageUrl,
      'status': status,
      'breedingType': breedingType,
      'bookingDate': bookingDate,
      'bookingTime': bookingTime,
      'notes': notes,
      'createdAt': createdAt,
      if (completedAt != null) 'completedAt': completedAt,
    };
  }
}
