import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/breeder/models/stud_pig_model.dart';

void main() {
  test('extra photos and health records save and load', () {
    final pig = StudPigModel.fromJson({
      'name': 'Duroc King',
      'imageUrl': 'main.jpg',
      'photoUrls': ['side.jpg', '', 42, 'pen.jpg'],
      'vaccinations': 'Hog cholera, FMD',
      'lastHealthCheck': '2026-09-01',
      'pedigree': 'PIC Duroc',
    }, 'p1');

    expect(pig.allPhotos, ['main.jpg', 'side.jpg', 'pen.jpg']);
    expect(pig.hasHealthInfo, isTrue);
    final json = pig.toJson();
    expect(json['photoUrls'], ['side.jpg', 'pen.jpg']);
    expect(json['lastHealthCheck'], '2026-09-01');
  });

  test('pigs listed before profiles existed still load', () {
    final pig = StudPigModel.fromJson({'name': 'Old Boar'}, 'p2');
    expect(pig.photoUrls, isEmpty);
    expect(pig.allPhotos, isEmpty);
    expect(pig.hasHealthInfo, isFalse);
  });
}
