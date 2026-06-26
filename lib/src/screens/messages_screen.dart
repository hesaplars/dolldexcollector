import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/web_image_helper.dart';

import '../../main.dart';

import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../core/local_storage_helper.dart';
import '../widgets/doll_widgets.dart';
import '../social/social_models.dart';
import '../users/user_models.dart';
import '../users/profile_setup_repository.dart';
import '../auth/sign_in_panel.dart';
import 'social_screen.dart';
import '../moderation/report_models.dart';
import '../catalog/catalog_models.dart';

class DirectMessagesModalContent extends StatefulWidget {
  const DirectMessagesModalContent({
    this.initialChatUserId,
    this.showDragHandle = true,
    super.key,
  });
  final String? initialChatUserId;
  final bool showDragHandle;

  @override
  State<DirectMessagesModalContent> createState() =>
      _DirectMessagesModalContentState();
}

class _DirectMessagesModalContentState
    extends State<DirectMessagesModalContent> {
  String? _activeThreadId;
  String? _activeChatUserId;
  bool _showFriendsSelection = false;
  bool _isLoading = false;

  List<String> _mutedThreadIds = [];
  Map<String, String> _lastReadTimes = {};
  String? _resolvedThreadForUserId;

  @override
  void initState() {
    super.initState();
    _loadMutedAndDeleted();
    if (widget.initialChatUserId != null) {
      _startChatWithUser(widget.initialChatUserId!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showDragHandle) {
      final state = GoRouterState.of(context);
      final chatUserId = state.uri.queryParameters['chatUserId'];
      final newChat = state.uri.queryParameters['newChat'] == 'true';

      if (chatUserId != null) {
        _activeChatUserId = chatUserId;
        _showFriendsSelection = false;
        _resolveActiveThreadForUser(chatUserId);
      } else if (newChat) {
        _activeThreadId = null;
        _activeChatUserId = null;
        _showFriendsSelection = true;
        _resolvedThreadForUserId = null;
      } else {
        _activeThreadId = null;
        _activeChatUserId = null;
        _showFriendsSelection = false;
        _resolvedThreadForUserId = null;
      }
    }
  }

  Future<void> _resolveActiveThreadForUser(String otherUserId) async {
    if (_resolvedThreadForUserId == otherUserId) return;
    _resolvedThreadForUserId = otherUserId;
    final myUid = authService.currentUser?.uid;
    if (myUid == null) return;
    try {
      final threadId = await socialRepository.openDirectThread(
        currentUserId: myUid,
        otherUserId: otherUserId,
      );
      if (mounted && _activeChatUserId == otherUserId) {
        setState(() {
          _activeThreadId = threadId;
        });
        _markThreadAsRead(threadId);
      }
    } catch (_) {}
  }

  Future<void> _loadMutedAndDeleted() async {
    final muted = await LocalStorage.getStringList('muted_threads');
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
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final confirmed = await showGothicConfirmDialog(
      context,
      title: tr ? 'Sohbeti Sil' : 'Delete Chat',
      content: tr
          ? 'Bu sohbeti silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'
          : 'Are you sure you want to delete this chat? This action cannot be undone.',
      confirmText: tr ? 'Sil' : 'Delete',
    );
    if (confirmed != true) return;

    final myUid = authService.currentUser?.uid ?? '';
    if (myUid.isNotEmpty) {
      await socialRepository.deleteThreadForUser(myUid, threadId);
    }
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
    if (!widget.showDragHandle) {
      context.go('/messages?chatUserId=$otherUserId');
      return;
    }
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
    if (!widget.showDragHandle) {
      context.go('/messages');
      return;
    }
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          buildGothicNeonIconButton(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            size: 36,
            padding: const EdgeInsets.all(12),
            activeColor: DollDexTheme.teal,
          ),
          const SizedBox(height: 16),
          Text(
            tr ? 'Mesajlarını Kontrol Et' : 'Check Your Messages',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              tr
                  ? 'Diğer koleksiyoncularla mesajlaşmak ve sohbet etmek için giriş yapmalısın.'
                  : 'You must sign in to message and chat with other collectors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const GuestLoginBanner(),
        ],
      );
    }

    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary));
    }

    Widget header;
    Widget body;

    if (_activeThreadId != null && _activeChatUserId != null) {
      header = Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          StreamBuilder<ProfileSetupStatus>(
            stream: profileSetupRepository.watch(_activeChatUserId!),
            builder: (context, snap) {
              final username = snap.data?.username.isNotEmpty == true
                  ? '@${snap.data!.username}'
                  : 'Collector';
              final avatarId = snap.data?.avatarId ?? '';
              final frameColor = snap.data?.avatarFrameColor ?? '';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.showDragHandle) {
                    Navigator.of(context).pop();
                  }
                  final uName = snap.data?.username ?? '';
                  if (uName.isNotEmpty) {
                    context.go('/u/$uName');
                  } else {
                    context.go('/users/${_activeChatUserId}');
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      buildAvatarHelper(context, avatarId, frameColor,
                          size: 32),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (snap.data?.selectedBadge.isNotEmpty == true) ...[
                            ProfileBadgeWidget(
                                badgeId: snap.data!.selectedBadge, size: 8),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            username,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
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
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          const SizedBox(width: 8),
          Text(
            tr ? 'Yeni Sohbet' : 'New Chat',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18),
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
                  tr
                      ? 'Sohbet başlatacak arkadaşınız yok'
                      : 'No friends to start chat with',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 14),
                ),
              );
            }
            return ListView.builder(
              key: const PageStorageKey('messages_friends_scroll'),
              itemCount: friends.length,
              itemBuilder: (context, idx) {
                final friend = friends[idx];
                return ListTile(
                  leading: buildAvatarHelper(
                      context, friend.avatarId, friend.avatarFrameColor,
                      size: 36),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (friend.selectedBadge.isNotEmpty) ...[
                        ProfileBadgeWidget(
                            badgeId: friend.selectedBadge, size: 8),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        friend.username.isEmpty
                            ? friend.displayName
                            : '@${friend.username}',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  subtitle: Text(friend.displayName,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12)),
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
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            IconButton(
              icon: Icon(Icons.add_comment_rounded,
                  color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                if (!widget.showDragHandle) {
                  context.go('/messages?newChat=true');
                } else {
                  setState(() => _showFriendsSelection = true);
                }
              },
            ),
          ],
        ),
      );

      body = Expanded(
        child: StreamBuilder<List<String>>(
          stream: socialRepository.watchDeletedThreads(myUid),
          builder: (context, deletedSnap) {
            final deletedIds = deletedSnap.data ?? [];
            return StreamBuilder<List<ChatThread>>(
              stream: socialRepository.watchChatThreads(myUid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allThreads = snap.data ?? [];
                final threads = allThreads
                    .where((t) => !deletedIds.contains(t.id))
                    .toList();
                if (threads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          tr ? 'Henüz konuşma yok' : 'No conversations yet',
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  key: const PageStorageKey('messages_inbox_scroll'),
                  itemCount: threads.length,
                  itemBuilder: (context, idx) {
                    final thread = threads[idx];
                    final otherMemberId = thread.memberIds
                        .firstWhere((id) => id != myUid, orElse: () => '');
                    if (otherMemberId.isEmpty) return const SizedBox.shrink();

                    return ThreadListTile(
                      thread: thread,
                      otherUserId: otherMemberId,
                      onTap: () {
                        if (!widget.showDragHandle) {
                          context.go('/messages?chatUserId=$otherMemberId');
                        } else {
                          setState(() {
                            _activeThreadId = thread.id;
                            _activeChatUserId = otherMemberId;
                          });
                          _markThreadAsRead(thread.id);
                        }
                      },
                      isMuted: _mutedThreadIds.contains(thread.id),
                      hasUnread: _isThreadUnread(thread, myUid),
                      onMute: () => _muteThread(thread.id),
                      onDelete: () => _deleteThread(thread.id),
                    );
                  },
                );
              },
            );
          },
        ),
      );
    }

    return PopScope(
      canPop: widget.showDragHandle
          ? (_activeThreadId == null && !_showFriendsSelection)
          : true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.showDragHandle &&
            (_activeThreadId != null || _showFriendsSelection)) {
          _backToInbox();
        }
      },
      child: Column(
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
          Divider(color: Theme.of(context).dividerColor, height: 1),
          body,
        ],
      ),
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
        final username =
            status.username.isNotEmpty ? '@${status.username}' : 'Collector';
        final displayName = status.displayName;
        final avatarId = status.avatarId;
        final frameColor = status.avatarFrameColor;

        final myUid = authService.currentUser?.uid ?? '';
        final isMe = thread.lastMessageSenderId == myUid;
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final prefix = isMe ? (tr ? 'Siz: ' : 'You: ') : '';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: onTap,
            leading: buildAvatarHelper(context, avatarId, frameColor, size: 46),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.selectedBadge.isNotEmpty) ...[
                  ProfileBadgeWidget(badgeId: status.selectedBadge, size: 8),
                  const SizedBox(height: 2),
                ],
                Text(
                  username,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                if (hasUnread) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (isMuted) ...[
                  Icon(Icons.volume_off_rounded,
                      size: 14,
                      color: isDark ? Colors.white30 : Colors.black38),
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
                      fontSize: 12.5,
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
              icon: Icon(Icons.more_vert_rounded,
                  color: isDark ? Colors.white30 : Colors.black38),
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
  State<DirectChatConversationView> createState() =>
      _DirectChatConversationViewState();
}

class _DirectChatConversationViewState
    extends State<DirectChatConversationView> {
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
                  LocalStorage.getString('last_read_times')
                      .then((readTimesRaw) {
                    Map<String, String> readTimes = {};
                    if (readTimesRaw != null) {
                      try {
                        readTimes = Map<String, String>.from(
                            jsonDecode(readTimesRaw) as Map);
                      } catch (_) {}
                    }
                    readTimes[widget.threadId] =
                        DateTime.now().toIso8601String();
                    LocalStorage.setString(
                        'last_read_times', jsonEncode(readTimes));
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
                key: const PageStorageKey('messages_chat_scroll'),
                reverse: true,
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        Divider(color: Theme.of(context).dividerColor, height: 1),
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
          ),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    builder: (context) {
                      return ShareItemSelectionModal(
                        userId: widget.myUid,
                        onShareCatalog: (catalogId) async {
                          await socialRepository.sendDirectMessage(
                            threadId: widget.threadId,
                            senderId: widget.myUid,
                            text: '',
                            sharedCatalogId: catalogId,
                            sharedSource: 'catalog',
                          );
                        },
                        onShareCollection:
                            (catalogId, collectionId, status) async {
                          await socialRepository.sendDirectMessage(
                            threadId: widget.threadId,
                            senderId: widget.myUid,
                            text: '',
                            sharedCatalogId: catalogId,
                            sharedCollectionId: collectionId,
                            sharedCollectionStatus: status,
                            sharedSource: 'collection',
                          );
                        },
                      );
                    },
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr ? 'Mesaj yaz...' : 'Write message...',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectMsgBubble(
      BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: tr ? 'Bildir' : 'Report',
              onPressed: () => showReportSheet(
                context,
                ReportTargetType.comment,
                msg.id,
              ),
              icon: buildNeonFlagIcon(context, size: 16),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                  minWidth: 50,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 18 : 4),
                    topRight: const Radius.circular(18),
                    bottomLeft: const Radius.circular(18),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  color: isMe ? null : Theme.of(context).colorScheme.surface,
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withRed(
                                (Theme.of(context).colorScheme.primary.red - 20)
                                    .clamp(0, 255)),
                          ],
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<ProfileSetupStatus>(
                      stream: profileSetupRepository.watch(msg.senderId),
                      builder: (context, snapshot) {
                        final badge = snapshot.data?.selectedBadge ?? '';
                        final username =
                            snapshot.data?.username ?? msg.senderUsername;
                        final displayUsername = username.isNotEmpty
                            ? '@$username'
                            : (isMe ? 'Ben' : 'Collector');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badge.isNotEmpty) ...[
                              ProfileBadgeWidget(badgeId: badge, size: 7),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              displayUsername,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: isMe
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.9)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        );
                      },
                    ),
                    if (msg.text.isNotEmpty) ...[
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: isMe
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    if (msg.sharedSource.isNotEmpty) ...[
                      _buildSharedItemCard(context, msg, isMe),
                    ],
                    if (msg.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          formatMessageTime(msg.createdAt!),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 8.5,
                            color: isMe
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedItemCard(
      BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final entry = catalogEntriesNotifier.value.firstWhere(
      (e) => e.id == msg.sharedCatalogId,
      orElse: () => CatalogEntry(
        id: '',
        name: '',
        type: CatalogItemType.doll,
        subtitle: '',
        imageUrls: [],
      ),
    );

    if (entry.id.isEmpty) {
      return const SizedBox.shrink();
    }

    String getStatusLabel(String status) {
      switch (status) {
        case 'owned':
          return tr ? 'Sahibim' : 'Owned';
        case 'wanted':
          return tr ? 'Arıyorum' : 'Looking For';
        case 'trade':
          return tr ? 'Takaslık' : 'Trade';
        case 'selling':
          return tr ? 'Satılık' : 'Selling';
        default:
          return status;
      }
    }

    final statusLabel = getStatusLabel(msg.sharedCollectionStatus);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.4)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/i/${entry.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: entry.primaryImageUrl.isNotEmpty
                          ? (kIsWeb
                              ? getWebImage(
                                  imageUrl: entry.primaryImageUrl,
                                  label: entry.name,
                                  fit: entry.primaryImageUrl
                                          .toLowerCase()
                                          .contains('.png')
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                )
                              : Image.network(
                                  entry.primaryImageUrl,
                                  fit: entry.primaryImageUrl
                                          .toLowerCase()
                                          .contains('.png')
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_rounded,
                                          size: 20, color: Colors.grey),
                                ))
                          : const Icon(Icons.image_not_supported_rounded,
                              size: 20, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (entry.series != null &&
                            entry.series!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            entry.series!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                        if (statusLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      await performGoogleSignIn(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: DirectMessagesModalContent(showDragHandle: false),
    );
  }
}
