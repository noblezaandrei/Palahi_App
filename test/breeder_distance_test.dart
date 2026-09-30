import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/breeder/models/breeder_model.dart';
import 'package:palahi/features/breeder/views/widgets/breeder_card.dart';

BreederModel _breeder(double lat, double lng) => BreederModel(
  id: 'b',
  userId: 'b',
  farmName: 'Farm',
  location: '',
  latitude: lat,
  longitude: lng,
  rating: 0,
  reviewCount: 0,
  imageUrl: '',
  about: '',
  services: const [],
);

void main() {
  test('distance is measured from the farm pin to the breeder', () {
    // 0.01° of latitude is about 1.11 km.
    final km = breederDistanceKm((
      lat: 13.18,
      lng: 123.66,
    ), _breeder(13.19, 123.66));
    expect(km, closeTo(1.11, 0.02));
  });

  test('no distance when either end is unknown', () {
    expect(breederDistanceKm(null, _breeder(13.19, 123.66)), isNull);
    // A breeder who never pinned their farm.
    expect(
      breederDistanceKm((lat: 13.18, lng: 123.66), _breeder(0, 0)),
      isNull,
    );
  });
}
