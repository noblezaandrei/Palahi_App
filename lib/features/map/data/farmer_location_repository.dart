import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return ref.watch(farmerLocationRepositoryProvider).watchLocation(farmerId);
});

/// Plain (lat, lng) pair — kept independent of any map package's LatLng type
/// since this is a data-layer file.
class FarmerLocation {
  final double latitude;
  final double longitude;
  const FarmerLocation(this.latitude, this.longitude);
}

class FarmerLocationRepository {
  final FirebaseFirestore _firestore;

  FarmerLocationRepository(this._firestore);

  FarmerLocation? _parse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return FarmerLocation(lat, lng);
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
        yield _parse(doc.data());
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
    });
  }
}
