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
  final String
  serviceType; // 'Natural Breeding', 'Artificial Insemination', or 'Both'
  final double rating;
  final int reviewCount;

  /// Extra photos beyond the main [imageUrl] (up to [maxExtraPhotos]).
  final List<String> photoUrls;

  /// Health and lineage, shown to farmers before they book. Free text,
  /// except [lastHealthCheck] (yyyy-MM-dd); empty when not given.
  final String vaccinations;
  final String lastHealthCheck;
  final String pedigree;

  static const maxExtraPhotos = 4;

  /// The main photo, then the extra ones.
  List<String> get allPhotos => [
    if (imageUrl.isNotEmpty) imageUrl,
    ...photoUrls.where((u) => u.isNotEmpty),
  ];

  bool get hasHealthInfo =>
      vaccinations.isNotEmpty ||
      lastHealthCheck.isNotEmpty ||
      pedigree.isNotEmpty;

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
    this.rating = 5.0,
    this.reviewCount = 0,
    this.photoUrls = const [],
    this.vaccinations = '',
    this.lastHealthCheck = '',
    this.pedigree = '',
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
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      photoUrls: [
        for (final url in (json['photoUrls'] as List?) ?? const [])
          if (url is String && url.isNotEmpty) url,
      ],
      vaccinations: json['vaccinations'] as String? ?? '',
      lastHealthCheck: json['lastHealthCheck'] as String? ?? '',
      pedigree: json['pedigree'] as String? ?? '',
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
      'rating': rating,
      'reviewCount': reviewCount,
      'photoUrls': photoUrls,
      'vaccinations': vaccinations,
      'lastHealthCheck': lastHealthCheck,
      'pedigree': pedigree,
    };
  }
}
