import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/features/communication/repositories/chat_repository.dart';
import 'package:palahi/features/communication/repositories/notification_repository.dart';
import 'package:palahi/features/auth/repositories/auth_repository.dart';
import 'package:palahi/core/constants/colors.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/user_avatar.dart';
import 'package:palahi/features/communication/viewmodels/chat_photos.dart';
import 'package:palahi/features/profile/viewmodels/own_photo_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  /// Shown until the room loads (it then comes from the room itself).
  final String otherParticipantName;
  final String otherParticipantImageUrl;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.otherParticipantName,
    this.otherParticipantImageUrl = '',
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _photoSync = OwnPhotoSync();

  /// Marks this conversation's message notifications read, so the badge
  /// doesn't count messages the user is looking at right now.
  // Id of the newest message already marked seen, so "seen" is only written
  // when a new message actually arrives, not on every rebuild.
  String? _seenUpToMessageId;

  void _markSeen(List<ChatMessageModel> messages) {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null || messages.isEmpty) return;
    final newestId = messages.last.id;
    if (_seenUpToMessageId == newestId) return;
    _seenUpToMessageId = newestId;
    ref.read(chatRepositoryProvider).markSeen(widget.roomId, uid).catchError((
      Object e,
    ) {
      debugPrint('Failed to mark chat seen: $e');
    });
    _markRoomRead();
  }

  void _markRoomRead() {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    ref
        .read(notificationRepositoryProvider)
        .markChatRoomNotificationsAsRead(uid, widget.roomId)
        .catchError((Object e) {
          debugPrint('Failed to mark chat notifications read: $e');
        });
  }

  @override
  void initState() {
    super.initState();
    _markRoomRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(
    String currentUserId,
    String currentUserName,
  ) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.roomId, currentUserId, currentUserName, text);
    } catch (e) {
      // Put the text back so a failed send doesn't silently lose the message.
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message not sent: ${friendlyError(e)}')),
      );
      return;
    }
    if (!mounted) return;

    // Auto scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final currentUserName = profileAsync.value?['name'] as String? ?? 'User';
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.roomId));
    final room = ref.watch(chatRoomStreamProvider(widget.roomId)).value;
    // Watched so a changed profile/farm photo is pushed to this chat.
    ref.watch(ownPhotoUrlProvider);
    if (room != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _photoSync.run(ref, user.uid, [room]);
      });
    }

    final otherName = room?.otherName(user.uid) ?? widget.otherParticipantName;
    var otherPhoto = room == null ? '' : chatPartnerPhoto(ref, room, user.uid);
    if (otherPhoto.isEmpty) otherPhoto = widget.otherParticipantImageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(
              name: otherName,
              imageUrl: otherPhoto,
              backgroundColor: Colors.white,
              initialColor: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                otherName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Send a message to start conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Schedule scroll to bottom on message list load/update, and
                // clear the badge for messages arriving while open.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markSeen(messages);
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                // "Seen" goes under my newest message once the other person
                // has had the chat open since it was sent.
                final room = ref
                    .watch(chatRoomStreamProvider(widget.roomId))
                    .value;
                DateTime? otherSeenAt;
                final seenBy = room?.seenBy ?? const <String, DateTime>{};
                for (final entry in seenBy.entries) {
                  if (entry.key != user.uid) otherSeenAt = entry.value;
                }
                final myLastIndex = messages.lastIndexWhere(
                  (m) => m.senderId == user.uid,
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == user.uid;
                    final showStatus = index == myLastIndex;
                    final seen =
                        otherSeenAt != null &&
                        !otherSeenAt.isBefore(msg.timestamp);

                    final bubble = Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (!showStatus) return bubble;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        bubble,
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                seen ? Icons.done_all : Icons.done,
                                size: 14,
                                color: seen ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                seen ? 'Seen' : 'Sent',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: seen ? AppColors.primary : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading messages: ${friendlyError(err)}'),
              ),
            ),
          ),

          // Send message area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    inputFormatters: [LengthLimitingTextInputFormatter(5000)],
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(user.uid, currentUserName),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(user.uid, currentUserName),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
