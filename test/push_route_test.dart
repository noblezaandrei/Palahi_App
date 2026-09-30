import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/core/services/push_notification_service.dart';

void main() {
  test('a tapped push opens the screen it is about', () {
    expect(routeForPush({'type': 'booking'}, 'u1'), '/breeding-requests');
    expect(routeForPush({'type': 'chat'}, 'u1'), '/messages');
    expect(routeForPush({'type': 'review'}, 'u1'), '/reviews/u1');
    expect(routeForPush({}, 'u1'), '/notifications');
  });
}
