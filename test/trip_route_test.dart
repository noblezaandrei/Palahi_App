import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/features/map/repositories/route_service.dart';

void main() {
  // A straight road heading north, a point every ~111 m (0.001°), 1 km long.
  final road = RoadRoute(
    points: [for (var i = 0; i <= 10; i++) LatLng(13.0 + i * 0.001, 123.7)],
    distanceKm: 1.0,
    duration: const Duration(minutes: 10),
  );

  test('the route still ahead shrinks as the breeder drives along it', () {
    final start = remainingRoute(road, const LatLng(13.0, 123.7));
    final halfway = remainingRoute(road, const LatLng(13.005, 123.7));

    expect(start.route.distanceKm, closeTo(1.0, 0.12));
    expect(halfway.route.distanceKm, closeTo(0.5, 0.12));
    expect(halfway.route.duration.inMinutes, inInclusiveRange(4, 6));
    expect(halfway.offRouteKm, lessThan(0.01));
  });

  test('the remaining line starts at the breeder and ends at the farm', () {
    const breeder = LatLng(13.0052, 123.7);
    final left = remainingRoute(road, breeder).route;

    expect(left.points.first, breeder);
    expect(left.points.last, road.points.last);
    // Nothing behind the breeder is drawn.
    expect(
      left.points.skip(1).every((p) => p.latitude > breeder.latitude),
      isTrue,
    );
  });

  test('a breeder at the farm has nothing left to drive', () {
    final left = remainingRoute(road, road.points.last).route;

    expect(left.distanceKm, closeTo(0, 0.001));
    expect(left.duration, Duration.zero);
  });

  test('the breeder only moves forward along the route', () {
    // Halfway along the road.
    expect(progressAlongRoute(road, const LatLng(13.005, 123.7)), 5);
    // Already past that point: a fix further back doesn't move them back.
    expect(
      progressAlongRoute(road, const LatLng(13.002, 123.7), reachedIndex: 5),
      isNull,
    );
    // Further along: they move on.
    expect(
      progressAlongRoute(road, const LatLng(13.008, 123.7), reachedIndex: 5),
      8,
    );
  });

  test('a GPS fix far from the route is ignored', () {
    // ~5 km east of the road, e.g. a breeder testing away from the farm.
    expect(progressAlongRoute(road, const LatLng(13.005, 123.746)), isNull);
  });
}
