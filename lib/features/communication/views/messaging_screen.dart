import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/utils/date_utils.dart';
import 'chat_room_screen.dart';
import 'package:palahi/features/communication/viewmodels/chat_photos.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/user_avatar.dart';
import 'package:palahi/features/profile/viewmodels/own_photo_provider.dart';

String getChatInboxRole(Map<String, dynamic>? profile) {
  final rawRole = profile?['role'] as String?;
  final normalized = rawRole?.trim().toLowerCase();
  return normalized == 'breeder' ? 'breeder' : 'farmer';
}

String getOtherParticipantName({
  required ChatRoomModel room,
  required String role,
}) {
  if (role == 'breeder') {
    return room.farmerName.isNotEmpty ? room.farmerName : 'Farmer';
  }

  return room.breederName.isNotEmpty ? room.breederName : 'Breeder';
}

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final _photoSync = OwnPhotoSync();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      ref
          .read(notificationRepositoryProvider)
          .markChatNotificationsAsRead(user.uid)
          .catchError((Object e) {
            // Only clears the unread badge; not worth interrupting the inbox.
            debugPrint('Failed to mark chat notifications read: $e');
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = getChatInboxRole(profileAsync.value);
    final chatRoomsAsync = ref.watch(chatRoomsStreamProvider(user.uid));
    // Watched so a changed profile/farm photo is pushed to every chat.
    ref.watch(ownPhotoUrlProvider);
    final rooms = chatRoomsAsync.value;
    if (rooms != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _photoSync.run(ref, user.uid, rooms);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Messages')),
      body: chatRoomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contact breeders via map or listings to chat.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final otherParticipantName = getOtherParticipantName(
                room: room,
                role: role,
              );
              final otherPhoto = chatPartnerPhoto(ref, room, user.uid);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: UserAvatar(
                    name: otherParticipantName,
                    imageUrl: otherPhoto,
                    radius: 24,
                  ),
                  title: Text(
                    otherParticipantName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    room.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    formatChatTime(room.lastMessageTime),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(
                          roomId: room.id,
                          otherParticipantName: otherParticipantName,
                          otherParticipantImageUrl: otherPhoto,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading inbox: ${friendlyError(err)}')),
      ),
    );
  }
}
