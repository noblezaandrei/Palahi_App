import 'package:palahi/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/home/views/farmer_dashboard_screen.dart';
import 'package:palahi/features/communication/views/messaging_screen.dart';

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

  test("chat room shows each side the other person's name and picture", () {
    final room = ChatRoomModel.fromJson({
      'farmerId': 'farmer_1',
      'farmerName': 'Farmer Joe',
      'farmerImageUrl': 'https://img/farmer.jpg',
      'breederId': 'breeder_1',
      'breederName': 'Green Valley',
      'breederImageUrl': 'https://img/farm.jpg',
      'participants': ['breeder_1', 'farmer_1'],
    }, 'breeder_1_farmer_1');

    expect(room.otherName('farmer_1'), 'Green Valley');
    expect(room.otherImageUrl('farmer_1'), 'https://img/farm.jpg');
    expect(room.otherId('farmer_1'), 'breeder_1');
    expect(room.otherName('breeder_1'), 'Farmer Joe');
    expect(room.otherImageUrl('breeder_1'), 'https://img/farmer.jpg');
    expect(room.otherId('breeder_1'), 'farmer_1');
  });

  test('chat rooms saved before pictures existed still load', () {
    final room = ChatRoomModel.fromJson({
      'farmerId': 'f',
      'breederId': 'b',
      'participants': ['b', 'f'],
    }, 'b_f');

    expect(room.otherImageUrl('f'), '');
    expect(room.otherImageUrl('b'), '');
    expect(room.otherName('f'), 'Breeder');
    expect(room.otherName('b'), 'Farmer');
    expect(room.toJson()['farmerImageUrl'], '');
  });

  test('a time slot that already started today cannot be booked', () {
    final now = DateTime(2026, 10, 1, 15, 0); // 3:00 PM
    final today = DateTime(2026, 10, 1);
    final tomorrow = DateTime(2026, 10, 2);

    expect(timeSlotHasPassed(today, '08:00 AM', now: now), isTrue);
    expect(timeSlotHasPassed(today, '03:00 PM', now: now), isTrue);
    expect(timeSlotHasPassed(today, '04:00 PM', now: now), isFalse);
    expect(timeSlotHasPassed(today, '12:00 PM', now: now), isTrue);
    expect(timeSlotHasPassed(tomorrow, '08:00 AM', now: now), isFalse);
    // 12:xx AM is just after midnight.
    expect(timeSlotHasPassed(tomorrow, '12:30 AM', now: now), isFalse);
    // Unknown formats never block a booking.
    expect(timeSlotHasPassed(today, 'morning', now: now), isFalse);
  });
}
