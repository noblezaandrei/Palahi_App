import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/auth/data/auth_repository.dart';
import 'package:palahi/features/communication/data/chat_repository.dart';
import 'package:palahi/features/home/presentation/screens/farmer_dashboard_screen.dart';
import 'package:palahi/features/communication/presentation/screens/messaging_screen.dart';

void main() {
  test(
    'safeUserProfileStream converts Firestore permission errors into null',
    () async {
      final stream = Stream<Map<String, dynamic>?>.fromFuture(
        Future.error(Exception('permission-denied')),
      );

      final result = await safeUserProfileStream(stream).toList();

      expect(result, [null]);
    },
  );

  test('greeting uses the role label when the profile name is missing', () {
    expect(getAppGreetingName({'role': 'farmer'}), 'Farmer');

    expect(getAppGreetingName({'role': 'breeder'}), 'Breeder');
  });

  test('inbox resolves the correct role and other participant name', () {
    expect(getChatInboxRole({'role': 'breeder'}), 'breeder');
    expect(getChatInboxRole({'role': 'FARMER'}), 'farmer');

    final room = ChatRoomModel(
      id: 'room_1',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Joe',
      breederId: 'breeder_1',
      breederName: 'Green Valley',
      lastMessage: 'Hi',
      lastMessageTime: DateTime(2024, 1, 1),
      participants: ['farmer_1', 'breeder_1'],
    );

    expect(getOtherParticipantName(room: room, role: 'breeder'), 'Farmer Joe');
    expect(getOtherParticipantName(room: room, role: 'farmer'), 'Green Valley');
  });
}
