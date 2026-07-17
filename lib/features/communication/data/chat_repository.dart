import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(FirebaseFirestore.instance);
});

final chatRoomsStreamProvider = StreamProvider.family<List<ChatRoomModel>, String>((ref, userId) {
  return ref.watch(chatRepositoryProvider).getChatRooms(userId);
});

final chatMessagesStreamProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).getMessages(roomId);
});

class ChatRoomModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String breederId;
  final String breederName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final List<String> participants;

  ChatRoomModel({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.breederId,
    required this.breederName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatRoomModel(
      id: id,
      farmerId: json['farmerId'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      breederName: json['breederName'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? (json['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      participants: List<String>.from(json['participants'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'breederId': breederId,
      'breederName': breederName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participants': participants,
    };
  }
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessageModel(
      id: id,
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository(this._firestore);

  /// Streams all chat rooms where the user is a participant.
  Stream<List<ChatRoomModel>> getChatRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatRoomModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  /// Streams messages in a specific chat room.
  Stream<List<ChatMessageModel>> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessageModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  /// Sends a message and updates the chat room.
  Future<void> sendMessage(String roomId, String senderId, String senderName, String text) async {
    final messageData = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    
    // Add message
    final msgRef = _firestore.collection('chat_rooms').doc(roomId).collection('messages').doc();
    batch.set(msgRef, messageData);

    // Update parent room
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    batch.update(roomRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Gets an existing chat room or creates a new one between farmer and breeder.
  Future<String> getOrCreateChatRoom({
    required String farmerId,
    required String farmerName,
    required String breederId,
    required String breederName,
  }) async {
    // Generate a unique room ID by sorting participants IDs
    final participants = [farmerId, breederId]..sort();
    final roomId = participants.join('_');

    final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
    
    if (!doc.exists) {
      final newRoom = ChatRoomModel(
        id: roomId,
        farmerId: farmerId,
        farmerName: farmerName,
        breederId: breederId,
        breederName: breederName,
        lastMessage: 'Chat started.',
        lastMessageTime: DateTime.now(),
        participants: participants,
      );
      await _firestore.collection('chat_rooms').doc(roomId).set(newRoom.toJson());
    }

    return roomId;
  }
}
