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

  /// Lets the user react to [msg]. Picking their current reaction again
  /// removes it.
  Future<void> _showReactionPicker(ChatMessageModel msg, String uid) async {
    HapticFeedback.selectionClick();
    final current = msg.reactions[uid];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current == null ? 'React to message' : 'Tap again to remove',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in chatReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => Navigator.pop(sheetContext, emoji),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emoji == current
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setReaction(
            widget.roomId,
            msg.id,
            uid,
            picked == current ? null : picked,
          )
          .withNetworkTimeout();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Reaction not saved: ${friendlyError(e)}')),
      );
    }
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

                    final hasReactions = msg.reactions.isNotEmpty;
                    final messageBox = Container(
                      margin: EdgeInsets.only(bottom: hasReactions ? 2 : 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary : Colors.grey.shade200,
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
                    );
                    final bubble = Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onLongPress: () =>
                                _showReactionPicker(msg, user.uid),
                            child: messageBox,
                          ),
                          if (hasReactions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReactionSummary(
                                reactions: msg.reactions,
                                myUid: user.uid,
                                onTap: () => _showReactionPicker(msg, user.uid),
                              ),
                            ),
                        ],
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

/// The reactions on a message: each emoji once, with a count when more than
/// one person picked it. Highlighted if one of them is the viewer's.
class _ReactionSummary extends StatelessWidget {
  final Map<String, String> reactions;
  final String myUid;
  final VoidCallback onTap;

  const _ReactionSummary({
    required this.reactions,
    required this.myUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final mine = reactions.containsKey(myUid);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mine ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          [
            for (final entry in counts.entries)
              entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
          ].join(' '),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
