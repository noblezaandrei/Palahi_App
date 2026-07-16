import 'package:cloud_firestore/cloud_firestore.dart';

class BreederModel {
  final String id;
  final String userId;
  final String farmName;
  final String location;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String about;
  final List<String> services;

  BreederModel({
    required this.id,
    required this.userId,
    required this.farmName,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.about,
    required this.services,
  });

  factory BreederModel.fromJson(Map<String, dynamic> json, String documentId) {
    GeoPoint? geoPoint = json['coordinates'] as GeoPoint?;
    
    return BreederModel(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      farmName: json['farmName'] as String? ?? 'Unknown Farm',
      location: json['location'] as String? ?? 'Unknown Location',
      latitude: geoPoint?.latitude ?? 0.0,
      longitude: geoPoint?.longitude ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      about: json['about'] as String? ?? '',
      services: List<String>.from(json['services'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'farmName': farmName,
      'location': location,
      'coordinates': GeoPoint(latitude, longitude),
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'about': about,
      'services': services,
    };
  }
}
