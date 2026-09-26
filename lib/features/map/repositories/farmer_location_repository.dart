import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';

final farmerLocationRepositoryProvider = Provider<FarmerLocationRepository>((
  ref,
) {
  return FarmerLocationRepository(FirebaseFirestore.instance);
});

/// A farmer's pinned farm location, kept in its own collection (rather than
/// on their `users` doc) so a breeder can fetch it by id for directions and
/// tracking without exposing the rest of the farmer's profile. It's a home
/// address, so the rules keep it private: readable only by the farmer and by
/// breeders one farmer at a time — never listed, never shown to other farmers.
final farmerLocationProvider = StreamProvider.family<FarmerLocation?, String>((
  ref,
  farmerId,
) {
  // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
  // a permission-denied error during logout stays cached empty forever.
  ref.watch(authStateProvider);
  return ref.watch(farmerLocationRepositoryProvider).watchLocation(farmerId);
});

/// A pinned farm — plain lat/lng kept independent of any map package's LatLng
/// type since this is a data-layer file. [name] and [imageUrl] are the only
/// profile details copied here (for breeders' trip maps); the rest of the
/// profile stays private in /users.
class FarmerLocation {
  final String farmerId;
  final double latitude;
  final double longitude;
  final String name;
  final String imageUrl;

  const FarmerLocation(
    this.latitude,
    this.longitude, {
    this.farmerId = '',
    this.name = '',
    this.imageUrl = '',
  });
}

class FarmerLocationRepository {
  final FirebaseFirestore _firestore;

  FarmerLocationRepository(this._firestore);

  FarmerLocation? _parse(Map<String, dynamic>? data, [String id = '']) {
    if (data == null) return null;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return FarmerLocation(
      lat,
      lng,
      farmerId: id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  Future<FarmerLocation?> getLocation(String farmerId) async {
    final doc = await _firestore
        .collection('farmer_locations')
        .doc(farmerId)
        .get();
    return _parse(doc.data());
  }

  Stream<FarmerLocation?> watchLocation(String farmerId) async* {
    try {
      await for (final doc
          in _firestore
              .collection('farmer_locations')
              .doc(farmerId)
              .snapshots()) {
        yield _parse(doc.data(), doc.id);
      }
    } catch (error) {
      debugPrint('Failed to watch farmer location: $error');
      yield null;
    }
  }

  Future<void> setLocation(String farmerId, double lat, double lng) {
    return _firestore.collection('farmer_locations').doc(farmerId).set({
      'latitude': lat,
      'longitude': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Copies the farmer's display name and photo onto their pin, so the
  /// breeder's trip map can show them. Does nothing until the farm is pinned.
  Future<void> syncPublicProfile(
    String farmerId, {
    required String name,
    required String imageUrl,
  }) async {
    final ref = _firestore.collection('farmer_locations').doc(farmerId);
    final doc = await ref.get();
    final data = doc.data();
    if (data == null) return;
    if (data['name'] == name && data['imageUrl'] == imageUrl) return;
    await ref.update({'name': name, 'imageUrl': imageUrl});
  }
}
