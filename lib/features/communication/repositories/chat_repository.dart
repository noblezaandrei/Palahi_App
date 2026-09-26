import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(FirebaseFirestore.instance);
});

final chatRoomsStreamProvider =
    StreamProvider.family<List<ChatRoomModel>, String>((ref, userId) {
      // Re-subscribe on sign-in/out — otherwise a stream that was cut off by
      // a permission-denied error during logout stays cached empty forever.
      ref.watch(authStateProvider);
      return ref.watch(chatRepositoryProvider).getChatRooms(userId);
    });

/// One chat room, live — used for the other person's "seen" time.
final chatRoomStreamProvider = StreamProvider.family<ChatRoomModel?, String>((
  ref,
  roomId,
) {
  ref.watch(authStateProvider);
  return ref.watch(chatRepositoryProvider).watchRoom(roomId);
});

final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, roomId) {
      ref.watch(authStateProvider);
      return ref.watch(chatRepositoryProvider).getMessages(roomId);
    });

class ChatRoomModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String breederId;
  final String breederName;

  /// Each side's picture (farmer: profile photo, breeder: farm photo),
  /// copied here because a breeder can't read a farmer's private profile.
  /// Each participant keeps their own up to date via [ChatRepository.syncOwnPhoto].
  final String farmerImageUrl;
  final String breederImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final List<String> participants;

  /// When each participant last had this conversation open (uid -> time).
  final Map<String, DateTime> seenBy;

  ChatRoomModel({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.breederId,
    required this.breederName,
    this.farmerImageUrl = '',
    this.breederImageUrl = '',
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
    this.seenBy = const {},
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatRoomModel(
      id: id,
      farmerId: json['farmerId'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? '',
      breederId: json['breederId'] as String? ?? '',
      breederName: json['breederName'] as String? ?? '',
      farmerImageUrl: json['farmerImageUrl'] as String? ?? '',
      breederImageUrl: json['breederImageUrl'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? (json['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      participants: List<String>.from(json['participants'] ?? []),
      seenBy: {
        for (final entry
            in ((json['seenBy'] as Map<String, dynamic>?) ?? {}).entries)
          if (entry.value is Timestamp)
            entry.key: (entry.value as Timestamp).toDate(),
      },
    );
  }

  bool _isFarmer(String userId) => userId == farmerId;

  /// The other participant's display name, from [userId]'s point of view.
  String otherName(String userId) {
    final name = _isFarmer(userId) ? breederName : farmerName;
    if (name.isNotEmpty) return name;
    return _isFarmer(userId) ? 'Breeder' : 'Farmer';
  }

  /// The other participant's picture, from [userId]'s point of view.
  String otherImageUrl(String userId) =>
      _isFarmer(userId) ? breederImageUrl : farmerImageUrl;

  /// The other participant's uid, from [userId]'s point of view.
  String otherId(String userId) => _isFarmer(userId) ? breederId : farmerId;

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'breederId': breederId,
      'breederName': breederName,
      'farmerImageUrl': farmerImageUrl,
      'breederImageUrl': breederImageUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participants': participants,
    };
  }
}

/// The reactions people can put on a chat message. Must match the list in
/// firestore.rules (chat messages).
const chatReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  /// Who reacted, and with which emoji (uid -> emoji). One per person.
  final Map<String, String> reactions;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.reactions = const {},
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
      reactions: {
        for (final entry
            in ((json['reactions'] as Map<String, dynamic>?) ?? {}).entries)
          if (entry.value is String) entry.key: entry.value as String,
      },
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
  Stream<List<ChatRoomModel>> getChatRooms(String userId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('chat_rooms')
              .where('participants', arrayContains: userId)
              .snapshots()) {
        final rooms = snapshot.docs
            .map((doc) => ChatRoomModel.fromJson(doc.data(), doc.id))
            .toList();

        rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        yield rooms;
      }
    } catch (error) {
      debugPrint('Failed to load chat rooms: $error');
      yield <ChatRoomModel>[];
    }
  }

  Stream<ChatRoomModel?> watchRoom(String roomId) async* {
    try {
      await for (final doc
          in _firestore.collection('chat_rooms').doc(roomId).snapshots()) {
        yield doc.exists ? ChatRoomModel.fromJson(doc.data()!, doc.id) : null;
      }
    } catch (error) {
      debugPrint('Failed to watch chat room: $error');
      yield null;
    }
  }

  /// Records that [userId] has seen the conversation up to now.
  Future<void> markSeen(String roomId, String userId) {
    return _firestore.collection('chat_rooms').doc(roomId).update({
      'seenBy.$userId': FieldValue.serverTimestamp(),
    });
  }

  /// Streams messages in a specific chat room.
  Stream<List<ChatMessageModel>> getMessages(String roomId) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('chat_rooms')
              .doc(roomId)
              .collection('messages')
              .orderBy('timestamp', descending: false)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => ChatMessageModel.fromJson(doc.data(), doc.id))
            .toList();
      }
    } catch (error) {
      debugPrint('Failed to load chat messages: $error');
      yield <ChatMessageModel>[];
    }
  }

  /// Sends a message and updates the chat room.
  Future<void> sendMessage(
    String roomId,
    String senderId,
    String senderName,
    String text,
  ) async {
    final messageData = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();

    // Add message
    final msgRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    batch.set(msgRef, messageData);

    // Update parent room
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    batch.update(roomRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Send notification to other participant
    try {
      final roomDoc = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .get();
      if (roomDoc.exists) {
        final data = roomDoc.data()!;
        final farmerId = data['farmerId'] as String? ?? '';
        final breederId = data['breederId'] as String? ?? '';
        final recipientId = (senderId == farmerId) ? breederId : farmerId;
        if (recipientId.isNotEmpty && recipientId != senderId) {
          await _firestore.collection('notifications').add({
            'userId': recipientId,
            'title': 'New message from $senderName',
            // A preview only: messages can be up to 5000 characters but the
            // rules cap notification bodies at 2000, and a longer body made
            // the whole notification fail.
            'body': text.length > 200 ? '${text.substring(0, 200)}…' : text,
            'type': 'chat',
            'referenceId': roomId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to create chat notification: $e');
    }
  }

  /// Copies [userId]'s current [imageUrl] onto their side of each of
  /// [rooms] that has an outdated one — so the other person sees their
  /// latest picture. Writes nothing when everything is already current.
  Future<void> syncOwnPhoto(
    String userId,
    String imageUrl,
    List<ChatRoomModel> rooms,
  ) async {
    final batch = _firestore.batch();
    var any = false;
    for (final room in rooms) {
      final String field;
      final String current;
      if (room.farmerId == userId) {
        field = 'farmerImageUrl';
        current = room.farmerImageUrl;
      } else if (room.breederId == userId) {
        field = 'breederImageUrl';
        current = room.breederImageUrl;
      } else {
        continue;
      }
      if (current == imageUrl) continue;
      batch.update(_firestore.collection('chat_rooms').doc(room.id), {
        field: imageUrl,
      });
      any = true;
    }
    if (any) await batch.commit();
  }

  /// Sets [userId]'s reaction on the other person's [message] to [emoji],
  /// or removes it when [emoji] is null, then tells the message's sender
  /// ("Andrei reacted ❤️ to your message"). Each person has at most one
  /// reaction per message, and can't react to their own messages.
  Future<void> setReaction({
    required String roomId,
    required ChatMessageModel message,
    required String userId,
    required String userName,
    required String? emoji,
  }) async {
    if (message.senderId == userId) {
      throw ArgumentError('You cannot react to your own message.');
    }

    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(message.id)
        .update({'reactions.$userId': emoji ?? FieldValue.delete()});

    if (emoji == null) return; // removing a reaction isn't news

    // The reaction is saved; a failed notification shouldn't undo that or
    // show as an error.
    try {
      final preview = message.text.length > 100
          ? '${message.text.substring(0, 100)}…'
          : message.text;
      await _firestore.collection('notifications').add({
        'userId': message.senderId,
        'title': '$userName reacted $emoji to your message',
        'body': '"$preview"',
        'type': 'chat',
        'referenceId': roomId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to create reaction notification: $e');
    }
  }

  /// Gets an existing chat room or creates a new one between farmer and breeder.
  Future<String> getOrCreateChatRoom({
    required String farmerId,
    required String farmerName,
    required String breederId,
    required String breederName,
    String farmerImageUrl = '',
    String breederImageUrl = '',
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
        farmerImageUrl: farmerImageUrl,
        breederImageUrl: breederImageUrl,
        lastMessage: 'Chat started.',
        lastMessageTime: DateTime.now(),
        participants: participants,
      );
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .set(newRoom.toJson());
    }

    return roomId;
  }
}
