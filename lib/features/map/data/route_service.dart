import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// A driving route along real roads.
class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;

  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.duration,
  });
}

/// Fetches road routes from the public OSRM server — free and keyless, but a
/// shared demo instance with no uptime guarantee. Swap the base URL for a
/// self-hosted OSRM or the Google Directions API if this goes to production.
class RouteService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Returns null when no route can be found or the request fails, so callers
  /// can fall back to a straight line.
  Future<RoadRoute?> getRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      '$_baseUrl/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (body['code'] != 'Ok' || routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final coords = (route['geometry']['coordinates'] as List)
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      if (coords.length < 2) return null;

      return RoadRoute(
        points: coords,
        distanceKm: (route['distance'] as num).toDouble() / 1000,
        duration: Duration(seconds: (route['duration'] as num).round()),
      );
    } catch (e) {
      debugPrint('Route lookup failed: $e');
      return null;
    }
  }
}

typedef RouteKey = ({
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
});

/// Rounds to ~100 m so small GPS jitter doesn't trigger a new lookup, and so
/// every screen asking about the same trip gets the very same route and ETA.
RouteKey routeKeyFor(LatLng from, LatLng to) {
  double r(double v) => (v * 1000).round() / 1000;
  return (
    fromLat: r(from.latitude),
    fromLng: r(from.longitude),
    toLat: r(to.latitude),
    toLng: r(to.longitude),
  );
}

/// One shared route lookup per (rounded) origin/destination pair, used by
/// both the trip map and the Map tab so they can't disagree.
final tripRouteProvider = FutureProvider.autoDispose
    .family<RoadRoute?, RouteKey>(
      (ref, key) => RouteService().getRoute(
        LatLng(key.fromLat, key.fromLng),
        LatLng(key.toLat, key.toLng),
      ),
    );
