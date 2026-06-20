import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../core/local_storage_helper.dart';
import '../widgets/doll_widgets.dart';
import '../social/social_models.dart';
import '../users/user_models.dart';
import '../users/profile_setup_repository.dart';

class DirectMessagesModalContent extends StatefulWidget {
  const DirectMessagesModalContent({
    this.initialChatUserId,
    this.showDragHandle = true,
    super.key,
  });
  final String? initialChatUserId;
  final bool showDragHandle;

  @override
  State<DirectMessagesModalContent> createState() => _DirectMessagesModalContentState();
}

class _DirectMessagesModalContentState extends State<DirectMessagesModalContent> {
  String? _activeThreadId;
  String? _activeChatUserId;
  bool _showFriendsSelection = false;
  bool _isLoading = false;

  List<String> _mutedThreadIds = [];
  List<String> _deletedThreadIds = [];
  Map<String, String> _lastReadTimes = {};

  @override
  void initState() {
    super.initState();
    _loadMutedAndDeleted();
    if (widget.initialChatUserId != null) {
      _startChatWithUser(widget.initialChatUserId!);
    }
  }

  Future<void> _loadMutedAndDeleted() async {
    final muted = await LocalStorage.getStringList('muted_threads');
    final deleted = await LocalStorage.getStringList('deleted_threads');
    final readTimesRaw = await LocalStorage.getString('last_read_times');
    Map<String, String> readTimes = {};
    if (readTimesRaw != null) {
      try {
        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _mutedThreadIds = muted;
        _deletedThreadIds = deleted;
        _lastReadTimes = readTimes;
      });
    }
  }

  Future<void> _muteThread(String threadId) async {
    final updated = List<String>.from(_mutedThreadIds);
    if (updated.contains(threadId)) {
      updated.remove(threadId);
    } else {
      updated.add(threadId);
    }
    await LocalStorage.setStringList('muted_threads', updated);
    setState(() {
      _mutedThreadIds = updated;
    });
  }

  Future<void> _deleteThread(String threadId) async {
    final updated = List<String>.from(_deletedThreadIds);
    if (!updated.contains(threadId)) {
      updated.add(threadId);
    }
    await LocalStorage.setStringList('deleted_threads', updated);
    setState(() {
      _deletedThreadIds = updated;
    });
  }

  Future<void> _markThreadAsRead(String threadId) async {
    final updated = Map<String, String>.from(_lastReadTimes);
    updated[threadId] = DateTime.now().toIso8601String();
    await LocalStorage.setString('last_read_times', jsonEncode(updated));
    if (mounted) {
      setState(() {
        _lastReadTimes = updated;
      });
    }
  }

  bool _isThreadUnread(ChatThread thread, String myUid) {
    if (thread.lastMessageSenderId == myUid) return false;
    if (thread.lastMessagePreview.isEmpty) return false;
    final lastReadStr = _lastReadTimes[thread.id];
    if (lastReadStr == null) return true;
    if (thread.updatedAt == null) return false;
    final lastRead = DateTime.tryParse(lastReadStr);
    if (lastRead == null) return true;
    return thread.updatedAt!.isAfter(lastRead);
  }

  Future<void> _startChatWithUser(String otherUserId) async {
    final myUid = authService.currentUser?.uid;
    if (myUid == null) return;
    setState(() => _isLoading = true);
    try {
      final threadId = await socialRepository.openDirectThread(
        currentUserId: myUid,
        otherUserId: otherUserId,
      );
      if (mounted) {
        setState(() {
          _activeThreadId = threadId;
          _activeChatUserId = otherUserId;
          _showFriendsSelection = false;
          _isLoading = false;
        });
        _markThreadAsRead(threadId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet başlatılamadı: $e')),
        );
      }
    }
  }

  void _backToInbox() {
    _loadMutedAndDeleted();
    setState(() {
      _activeThreadId = null;
      _activeChatUserId = null;
      _showFriendsSelection = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final myUid = authService.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (myUid.isEmpty) {
      return Center(
        child: Text(
          tr ? 'Lütfen önce giriş yapın' : 'Please sign in first',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEC008C)));
    }

    Widget header;
    Widget body;

    if (_activeThreadId != null && _activeChatUserId != null) {
      header = Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          StreamBuilder<ProfileSetupStatus>(
            stream: profileSetupRepository.watch(_activeChatUserId!),
            builder: (context, snap) {
              final username = snap.data?.username.isNotEmpty == true ? '@${snap.data!.username}' : 'Collector';
              final avatarId = snap.data?.avatarId ?? '';
              final frameColor = snap.data?.avatarFrameColor ?? '';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.showDragHandle) {
                    Navigator.of(context).pop();
                  }
                  context.push('/users/${_activeChatUserId}');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      buildAvatarHelper(avatarId, frameColor, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
      body = Expanded(
        child: DirectChatConversationView(
          threadId: _activeThreadId!,
          otherUserId: _activeChatUserId!,
          myUid: myUid,
        ),
      );
    } else if (_showFriendsSelection) {
      header = Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          const SizedBox(width: 8),
          Text(
            tr ? 'Yeni Sohbet' : 'New Chat',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      );
      body = Expanded(
        child: StreamBuilder<List<AppUser>>(
          stream: socialRepository.watchFriendsList(myUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final friends = snap.data ?? [];
            if (friends.isEmpty) {
              return Center(
                child: Text(
                  tr ? 'Sohbet başlatacak arkadaşınız yok' : 'No friends to start chat with',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                ),
              );
            }
            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, idx) {
                final friend = friends[idx];
                return ListTile(
                  leading: buildAvatarHelper(friend.avatarId, friend.avatarFrameColor, size: 36),
                  title: Text(
                    friend.username.isEmpty ? friend.displayName : '@${friend.username}',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(friend.displayName, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  onTap: () => _startChatWithUser(friend.id),
                );
              },
            );
          },
        ),
      );
    } else {
      header = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr ? 'Özel Mesajlar' : 'Direct Messages',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_rounded, color: Color(0xFFEC008C)),
              onPressed: () => setState(() => _showFriendsSelection = true),
            ),
          ],
        ),
      );

      body = Expanded(
        child: StreamBuilder<List<ChatThread>>(
          stream: socialRepository.watchChatThreads(myUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allThreads = snap.data ?? [];
            final threads = allThreads.where((t) => !_deletedThreadIds.contains(t.id)).toList();
            if (threads.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      tr ? 'Henüz konuşma yok' : 'No conversations yet',
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: threads.length,
              itemBuilder: (context, idx) {
                final thread = threads[idx];
                final otherMemberId = thread.memberIds.firstWhere((id) => id != myUid, orElse: () => '');
                if (otherMemberId.isEmpty) return const SizedBox.shrink();

                return ThreadListTile(
                  thread: thread,
                  otherUserId: otherMemberId,
                  onTap: () {
                    setState(() {
                      _activeThreadId = thread.id;
                      _activeChatUserId = otherMemberId;
                    });
                    _markThreadAsRead(thread.id);
                  },
                  isMuted: _mutedThreadIds.contains(thread.id),
                  hasUnread: _isThreadUnread(thread, myUid),
                  onMute: () => _muteThread(thread.id),
                  onDelete: () => _deleteThread(thread.id),
                );
              },
            );
          },
        ),
      );
    }

    return Column(
      children: [
        if (widget.showDragHandle) ...[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 8),
        header,
        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
        body,
      ],
    );
  }
}

class ThreadListTile extends StatelessWidget {
  const ThreadListTile({
    required this.thread,
    required this.otherUserId,
    required this.onTap,
    required this.isMuted,
    required this.hasUnread,
    required this.onMute,
    required this.onDelete,
    super.key,
  });

  final ChatThread thread;
  final String otherUserId;
  final VoidCallback onTap;
  final bool isMuted;
  final bool hasUnread;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(otherUserId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 60);
        }
        final status = snap.data!;
        final username = status.username.isNotEmpty ? '@${status.username}' : 'Collector';
        final displayName = status.displayName;
        final avatarId = status.avatarId;
        final frameColor = status.avatarFrameColor;

        final myUid = authService.currentUser?.uid ?? '';
        final isMe = thread.lastMessageSenderId == myUid;
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final prefix = isMe ? (tr ? 'Siz: ' : 'You: ') : '';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListTile(
          onTap: onTap,
          leading: buildAvatarHelper(avatarId, frameColor, size: 40),
          title: Text(
            username,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Row(
            children: [
              if (hasUnread) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEC008C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isMuted) ...[
                Icon(Icons.volume_off_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  thread.lastMessagePreview.isNotEmpty
                      ? '$prefix${thread.lastMessagePreview}'
                      : displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
              if (thread.updatedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatMessageTime(thread.updatedAt!),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white24 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white30 : Colors.black38),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'mute') {
                onMute();
              } else if (val == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(
                  isMuted
                      ? (tr ? 'Sesi Aç' : 'Unmute')
                      : (tr ? 'Sessize Al' : 'Mute'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  tr ? 'Sohbeti Sil' : 'Delete',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DirectChatConversationView extends StatefulWidget {
  const DirectChatConversationView({
    required this.threadId,
    required this.otherUserId,
    required this.myUid,
    super.key,
  });

  final String threadId;
  final String otherUserId;
  final String myUid;

  @override
  State<DirectChatConversationView> createState() => _DirectChatConversationViewState();
}

class _DirectChatConversationViewState extends State<DirectChatConversationView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();
    await socialRepository.sendDirectMessage(
      threadId: widget.threadId,
      senderId: widget.myUid,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: socialRepository.watchDirectMessages(widget.threadId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snap.data ?? [];
              if (messages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  LocalStorage.getString('last_read_times').then((readTimesRaw) {
                    Map<String, String> readTimes = {};
                    if (readTimesRaw != null) {
                      try {
                        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
                      } catch (_) {}
                    }
                    readTimes[widget.threadId] = DateTime.now().toIso8601String();
                    LocalStorage.setString('last_read_times', jsonEncode(readTimes));
                  });
                });
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    tr ? 'Konuşmayı başlatın...' : 'Start the conversation...',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  final isMe = msg.senderId == widget.myUid;
                  return _buildDirectMsgBubble(context, msg, isMe);
                },
              );
            },
          ),
        ),
        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
          ),
          color: isDark ? const Color(0xFF171026) : const Color(0xFFFAF2FF),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr ? 'Mesaj yaz...' : 'Write message...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFFEC008C)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectMsgBubble(BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
            minWidth: 50,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C1F45), const Color(0xFF1C1330)]
                        : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13.5,
                ),
              ),
              if (msg.createdAt != null) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    formatMessageTime(msg.createdAt!),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 8.5,
                      color: isMe ? Colors.white70 : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t(context, 'socialSignInRequired')),
          ),
        ),
      );
    }

    return const SafeArea(
      child: DirectMessagesModalContent(showDragHandle: false),
    );
  }
}
