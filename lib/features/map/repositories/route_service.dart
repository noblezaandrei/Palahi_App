import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:palahi/core/utils/location_utils.dart';

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

/// Fetches road routes from the public OSRM demo server — free and keyless,
/// but shared and without an uptime guarantee, so this follows its usage
/// policy (https://github.com/Project-OSRM/osrm-backend/wiki/Api-usage-policy):
/// it identifies the app, sends at most one request per second, and caches
/// results so reopening a map doesn't ask again. Callers fall back to a
/// straight line when no route comes back. To move to a paid provider later,
/// only [_fetch] needs to change.
class RouteService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Sent as the User-Agent, as the policy asks. (Browsers don't allow
  /// setting it, so web requests go without.)
  static const _userAgent = 'PALAHI-mobile-app (stud pig booking, Albay PH)';

  static const _minGap = Duration(seconds: 1);
  static const _cacheFor = Duration(minutes: 30);
  // A failed lookup is remembered briefly so a broken server isn't asked
  // again on every rebuild.
  static const _failureCacheFor = Duration(minutes: 1);

  // Shared by every RouteService, since the limits apply to the whole app.
  static final _cache = <String, ({RoadRoute? route, DateTime until})>{};
  static final _inFlight = <String, Future<RoadRoute?>>{};
  static Future<void> _queue = Future.value();
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Returns null when no route can be found or the request fails, so callers
  /// can fall back to a straight line.
  Future<RoadRoute?> getRoute(LatLng from, LatLng to) {
    final key =
        '${from.latitude},${from.longitude};${to.latitude},${to.longitude}';

    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.until)) {
      return Future.value(cached.route);
    }
    // Several screens asking for the same route share one request.
    return _inFlight[key] ??= _throttled(() => _fetchWithRetry(from, to))
        .then((route) {
          // Oldest first (insertion order), so a long trip can't grow it
          // without bound.
          if (_cache.length >= 200) _cache.remove(_cache.keys.first);
          _cache[key] = (
            route: route,
            until: DateTime.now().add(
              route == null ? _failureCacheFor : _cacheFor,
            ),
          );
          return route;
        })
        .whenComplete(() => _inFlight.remove(key));
  }

  /// Runs [request] after any earlier ones, at least [_minGap] apart.
  static Future<T> _throttled<T>(Future<T> Function() request) {
    final result = _queue.then((_) async {
      final wait = _lastRequest.add(_minGap).difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _lastRequest = DateTime.now();
      return request();
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// One retry for a busy or briefly unreachable server.
  Future<RoadRoute?> _fetchWithRetry(LatLng from, LatLng to) async {
    final first = await _fetch(from, to);
    if (first.route != null || !first.retryable) return first.route;
    await Future<void>.delayed(const Duration(seconds: 2));
    _lastRequest = DateTime.now();
    return (await _fetch(from, to)).route;
  }

  Future<({RoadRoute? route, bool retryable})> _fetch(
    LatLng from,
    LatLng to,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final response = await http
          .get(uri, headers: kIsWeb ? null : {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      // Rate-limited or server trouble: worth one more try.
      if (response.statusCode == 429 || response.statusCode >= 500) {
        return (route: null, retryable: true);
      }
      if (response.statusCode != 200) return (route: null, retryable: false);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (body['code'] != 'Ok' || routes == null || routes.isEmpty) {
        return (route: null, retryable: false);
      }

      final route = routes.first as Map<String, dynamic>;
      final coords = (route['geometry']['coordinates'] as List)
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      if (coords.length < 2) return (route: null, retryable: false);

      return (
        route: RoadRoute(
          points: coords,
          distanceKm: (route['distance'] as num).toDouble() / 1000,
          duration: Duration(seconds: (route['duration'] as num).round()),
        ),
        retryable: false,
      );
    } on TimeoutException catch (e) {
      debugPrint('Route lookup timed out: $e');
      return (route: null, retryable: true);
    } catch (e) {
      debugPrint('Route lookup failed: $e');
      return (route: null, retryable: false);
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

/// Looks up the route for [key] exactly as [tripRouteProvider] does, for code
/// that has no provider ref (the breeder's trip tracker).
Future<RoadRoute?> fetchTripRoute(RouteKey key) => RouteService().getRoute(
  LatLng(key.fromLat, key.fromLng),
  LatLng(key.toLat, key.toLng),
);

/// A GPS fix further than this from the trip's route is ignored — e.g. the
/// phone's first rough fix, or a breeder testing the app away from the farm —
/// so the breeder's icon never jumps off the road between the two farm pins.
const double offRouteLimitKm = 1.0;

/// The index of the point on [route] that the breeder at [position] has
/// reached, or null to leave their icon where it is: when the fix is more
/// than [offRouteLimitKm] from the route, or isn't past [reachedIndex]. The
/// icon only ever moves forward, toward the farm, so GPS jitter can't make
/// it wander back and forth.
int? progressAlongRoute(
  RoadRoute route,
  LatLng position, {
  int reachedIndex = 0,
}) {
  var nearest = -1;
  var nearestKm = double.infinity;
  for (var i = 0; i < route.points.length; i++) {
    final d = _km(route.points[i], position);
    if (d < nearestKm) {
      nearestKm = d;
      nearest = i;
    }
  }
  if (nearest <= reachedIndex || nearestKm > offRouteLimitKm) return null;
  return nearest;
}

double _km(LatLng a, LatLng b) => LocationUtils.getDistanceKm(
  a.latitude,
  a.longitude,
  b.latitude,
  b.longitude,
);

double _lengthKm(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _km(points[i - 1], points[i]);
  }
  return total;
}

/// What's left of [route] for a breeder at [position]: the road from the
/// route point nearest to them onwards, starting at [position], with the
/// distance and time scaled down to match. [offRouteKm] is how far
/// [position] is from the route.
({RoadRoute route, double offRouteKm}) remainingRoute(
  RoadRoute route,
  LatLng position,
) {
  final points = route.points;
  var nearest = 0;
  var nearestKm = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = _km(points[i], position);
    if (d < nearestKm) {
      nearestKm = d;
      nearest = i;
    }
  }
  // Skip the nearest point itself: the breeder is usually just past it, and
  // drawing back to it would make the line double back behind them.
  final ahead = points.sublist(
    nearest + 1 < points.length ? nearest + 1 : points.length - 1,
  );
  final remaining = [position, ...ahead];
  final fullKm = _lengthKm(points);
  final share = fullKm <= 0
      ? 1.0
      : (_lengthKm(remaining) / fullKm).clamp(0.0, 1.0);
  return (
    route: RoadRoute(
      points: remaining,
      distanceKm: route.distanceKm * share,
      duration: route.duration * share,
    ),
    offRouteKm: nearestKm,
  );
}
