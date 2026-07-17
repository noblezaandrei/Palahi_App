class StudPigModel {
  final String id;
  final String breederId;
  final String name;
  final String breed;
  final int ageMonths;
  final double weight;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final String description;
  final String serviceType; // 'Natural Breeding', 'Artificial Insemination', or 'Both'

  StudPigModel({
    required this.id,
    required this.breederId,
    required this.name,
    required this.breed,
    required this.ageMonths,
    required this.weight,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.description,
    required this.serviceType,
  });

  factory StudPigModel.fromJson(Map<String, dynamic> json, String documentId) {
    return StudPigModel(
      id: documentId,
      breederId: json['breederId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      ageMonths: json['ageMonths'] as int? ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'Both',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breederId': breederId,
      'name': name,
      'breed': breed,
      'ageMonths': ageMonths,
      'weight': weight,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'description': description,
      'serviceType': serviceType,
    };
  }
}
