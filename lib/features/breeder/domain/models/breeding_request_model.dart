class BreedingRequestModel {
  final String id;
  final String farmerId;
  final String breederId;
  final String studPigId;
  final String studPigName;
  final String status; // 'pending', 'approved', 'rejected'
  final String message;
  final DateTime timestamp;

  BreedingRequestModel({
    required this.id,
    required this.farmerId,
    required this.breederId,
    required this.studPigId,
    required this.studPigName,
    required this.status,
    required this.message,
    required this.timestamp,
  });

  factory BreedingRequestModel.fromJson(Map<String, dynamic> json, String documentId) {
    return BreedingRequestModel(
      id: documentId,
      farmerId: json['farmerId'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      studPigId: json['studPigId'] as String? ?? '',
      studPigName: json['studPigName'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'].millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'breederId': breederId,
      'studPigId': studPigId,
      'studPigName': studPigName,
      'status': status,
      'message': message,
      'timestamp': timestamp,
    };
  }
}
