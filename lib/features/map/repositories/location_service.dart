import 'package:geolocator/geolocator.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/map/repositories/farmer_location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentLocationProvider = FutureProvider<Position>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentLocation();
});

class LocationService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }
}

/// Where distances to breeders are measured from: the farmer's pinned farm
/// (the same point the Map tab uses), or the phone's location when there's
/// no pin. Null while neither is known.
final distanceOriginProvider = Provider<({double lat, double lng})?>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid != null) {
    final pin = ref.watch(farmerLocationProvider(uid)).value;
    if (pin != null) return (lat: pin.latitude, lng: pin.longitude);
  }
  final position = ref.watch(currentLocationProvider).value;
  return position == null
      ? null
      : (lat: position.latitude, lng: position.longitude);
});
