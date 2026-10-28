import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/features/map/repositories/route_service.dart';

void main() {
  // Two equal legs along a line of latitude, about 1.1 km each.
  const a = LatLng(13.10, 123.60);
  const b = LatLng(13.10, 123.61);
  const c = LatLng(13.10, 123.62);
  const route = RoadRoute(
    points: [a, b, c],
    distanceKm: 2.2,
    duration: Duration(minutes: 10),
  );

  test('start of the route is the breeder pin, nothing travelled', () {
    final split = splitRouteAt(route, 0);
    expect(split.point, a);
    expect(split.remaining.distanceKm, closeTo(2.2, 1e-9));
    expect(split.remaining.duration, const Duration(minutes: 10));
  });

  test('halfway lands on the middle point with half left', () {
    final split = splitRouteAt(route, 0.5);
    expect(split.point.longitude, closeTo(123.61, 1e-6));
    expect(split.remaining.distanceKm, closeTo(1.1, 1e-9));
    expect(split.remaining.duration, const Duration(minutes: 5));
    expect(split.remaining.points.last, c);
  });

  test('a quarter of the way is between the first two points', () {
    final split = splitRouteAt(route, 0.25);
    expect(split.point.longitude, closeTo(123.605, 1e-6));
    expect(split.remaining.points, [split.point, b, c]);
  });

  test('the end is the farm, nothing left', () {
    final split = splitRouteAt(route, 1);
    expect(split.point, c);
    expect(split.remaining.distanceKm, 0);
    expect(split.remaining.duration, Duration.zero);
  });

  test('fractionAlongRoute matches the nearest route point', () {
    expect(fractionAlongRoute(route, a), 0);
    expect(
      fractionAlongRoute(route, const LatLng(13.1001, 123.61)),
      closeTo(0.5, 1e-6),
    );
    expect(fractionAlongRoute(route, c), 1);
  });
}
