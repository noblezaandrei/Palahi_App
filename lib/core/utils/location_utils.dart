import 'package:geolocator/geolocator.dart';

class LocationUtils {
  // Center of Camalig, Albay (Town Center / Municipal Hall area)
  static const double camaligCenterLatitude = 13.1300;
  static const double camaligCenterLongitude = 123.6300;

  // Approximate geographical boundaries of Camalig, Albay
  static const double minLat = 13.05;
  static const double maxLat = 13.22;
  static const double minLng = 123.55;
  static const double maxLng = 123.70;

  /// Checks if the given latitude and longitude are within Camalig, Albay
  static bool isInCamaligAlbay(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// Calculates the distance between two points in kilometers
  static double getDistanceKm(double startLat, double startLng, double endLat, double endLng) {
    final double distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceInMeters / 1000.0;
  }
}
