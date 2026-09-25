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
/// on their `users` doc) so it can be readable by any signed-in breeder for
/// directions/tracking without exposing the rest of the farmer's profile —
/// same idea as breeders' own coordinates already being public.
final farmerLocationProvider = StreamProvider.family<FarmerLocation?, String>((
  ref,
  farmerId,
) {
  // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
  // a permission-denied error during logout stays cached empty forever.
  ref.watch(authStateProvider);
  return ref.watch(farmerLocationRepositoryProvider).watchLocation(farmerId);
});

/// Every farmer's pinned farm, for the shared Map tab where all farmers see
/// each other.
final allFarmerLocationsProvider = StreamProvider<List<FarmerLocation>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(farmerLocationRepositoryProvider).watchAll();
});

/// A pinned farm — plain lat/lng kept independent of any map package's LatLng
/// type since this is a data-layer file. [name] and [imageUrl] are the only
/// profile details made public here (for other farmers' map pins); the rest
/// of the profile stays private in /users.
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

  Stream<List<FarmerLocation>> watchAll() async* {
    try {
      await for (final snapshot
          in _firestore.collection('farmer_locations').snapshots()) {
        yield snapshot.docs
            .map((doc) => _parse(doc.data(), doc.id))
            .whereType<FarmerLocation>()
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to watch farmer locations: $error');
      yield <FarmerLocation>[];
    }
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

  /// Copies the farmer's display name and photo onto their pin, so other
  /// farmers' maps can show them. Does nothing until the farm is pinned.
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
