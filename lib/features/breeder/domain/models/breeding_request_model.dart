class BreedingRequestModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String breederId;
  final String breederName;
  final String studPigId;
  final String studPigName;
  final String studPigImageUrl;
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final String serviceType; // 'Natural Breeding' or 'Artificial Insemination'
  final String message;
  final DateTime timestamp;

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
    required this.serviceType,
    required this.message,
    required this.timestamp,
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
      serviceType: json['serviceType'] as String? ?? 'Natural Breeding',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'].millisecondsSinceEpoch)
          : DateTime.now(),
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
      'serviceType': serviceType,
      'message': message,
      'timestamp': timestamp,
    };
  }
}
