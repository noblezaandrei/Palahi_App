class BreederMock {
  final String id;
  final String name;
  final String location;
  final double rating;
  final int reviewCount;
  final double distance;
  final String imageUrl;

  BreederMock({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.imageUrl,
  });
}

final List<BreederMock> mockBreeders = [
  BreederMock(
    id: '1',
    name: 'Green Valley Farms',
    location: 'San Miguel, Bulacan',
    rating: 4.8,
    reviewCount: 32,
    distance: 2.5,
    imageUrl: 'https://images.unsplash.com/photo-1604848698030-c434ba08ece1?auto=format&fit=crop&w=300&q=80',
  ),
  BreederMock(
    id: '2',
    name: 'Lucky 7 Genetics',
    location: 'Dona Remedios, Bulacan',
    rating: 4.6,
    reviewCount: 27,
    distance: 3.7,
    imageUrl: 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?auto=format&fit=crop&w=300&q=80',
  ),
  BreederMock(
    id: '3',
    name: 'Triple A Hog Farm',
    location: 'Baliuag, Bulacan',
    rating: 4.7,
    reviewCount: 16,
    distance: 5.1,
    imageUrl: 'https://images.unsplash.com/photo-1628144645223-1d07ecad6060?auto=format&fit=crop&w=300&q=80',
  ),
  BreederMock(
    id: '4',
    name: 'Quality Genetics PH',
    location: 'Pulilan, Bulacan',
    rating: 4.5,
    reviewCount: 15,
    distance: 6.2,
    imageUrl: 'https://images.unsplash.com/photo-1542455113-189f7f45b37f?auto=format&fit=crop&w=300&q=80',
  ),
];
