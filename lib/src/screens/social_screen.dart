import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../social/social_models.dart';
import '../users/user_models.dart';
import '../widgets/doll_widgets.dart';
import '../catalog/catalog_models.dart';
import '../comments/comment_models.dart';
import '../users/profile_setup_repository.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({this.chatUserId, super.key});

  final String? chatUserId;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.chatUserId != null && widget.chatUserId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openDirectChatWithUser(context, widget.chatUserId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

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

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t(context, 'social'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                  ),
                  const Spacer(),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: tr ? 'Sohbet' : 'Chat'),
                      Tab(text: tr ? 'Akış' : 'Feed'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF6FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF00FFCC).withOpacity(0.25)
                        : const Color(0xFFEC008C).withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C)).withOpacity(0.08),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildNeonIcon(context, Icons.info_outline_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(context, 'socialSubtitle'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFC4B2D9) : const Color(0xFF6B5885),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _PendingRequestsCard(userId: user.uid),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _GlobalChatCard(
                      userId: user.uid,
                    ),
                    _SocialFeedTab(
                      userId: user.uid,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalChatCard extends StatefulWidget {
  const _GlobalChatCard({
    required this.userId,
  });

  final String userId;

  @override
  State<_GlobalChatCard> createState() => _GlobalChatCardState();
}

class _GlobalChatCardState extends State<_GlobalChatCard> {
  final _globalMessageController = TextEditingController();
  final _searchController = TextEditingController();
  final _globalMessageFocusNode = FocusNode();
  List<AppUser> _results = const <AppUser>[];
  bool _isSearching = false;
  bool _showSearchInput = false;

  @override
  void dispose() {
    _globalMessageController.dispose();
    _searchController.dispose();
    _globalMessageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text;
    if (query.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final users = await socialRepository.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = users
            .where((user) => user.id != widget.userId)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'socialSearchFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    await socialRepository.sendFriendRequest(
      fromUserId: widget.userId,
      toUserId: targetUserId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'friendRequestSent'))),
    );
  }

  Future<void> _sendGlobalMessage() async {
    if (_globalMessageController.text.trim().isEmpty) return;
    final text = _globalMessageController.text;
    _globalMessageController.clear();
    _globalMessageFocusNode.requestFocus();
    await socialRepository.sendGlobalMessage(
      senderId: widget.userId,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  t(context, 'globalChat'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _showSearchInput ? 180.0 : 0.0,
                  height: 36,
                  curve: Curves.easeInOut,
                  child: _showSearchInput
                      ? TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _searchUsers(),
                          style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Colors.white),
                          decoration: InputDecoration(
                            hintText: t(context, 'searchUsername'),
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFFEC008C), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                            ),
                            suffixIcon: _isSearching
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC008C)),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _results = const [];
                                        _showSearchInput = false;
                                      });
                                    },
                                  ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (!_showSearchInput)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearchInput = true;
                      });
                    },
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF00FFCC), size: 20),
                    label: Text(
                      tr ? 'Kullanıcı Ara' : 'Search User',
                      style: const TextStyle(
                        color: Color(0xFF00FFCC),
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171026) : const Color(0xFFFAF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.3)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final target = _results[index];
                    return ListTile(
                      dense: true,
                      leading: buildAvatarHelper(target.avatarId, target.avatarFrameColor, size: 28),
                      title: Text(
                        target.username.isEmpty ? target.displayName : '@${target.username}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF00FFCC)),
                            onPressed: () => _sendFriendRequest(target.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle_outlined, size: 18, color: Color(0xFFEC008C)),
                            onPressed: () => context.push('/users/${target.id}'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: socialRepository.watchGlobalChat(),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? const <ChatMessage>[];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(t(context, 'globalChatEmpty')),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.userId;
                      return _buildGlobalMsgBubble(context, message, isMe);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _globalMessageController,
                    focusNode: _globalMessageFocusNode,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendGlobalMessage(),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: t(context, 'globalMessage'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendGlobalMessage,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC008C).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalMsgBubble(BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => context.push('/users/${msg.senderId}'),
              child: buildAvatarHelper(msg.senderAvatarId, msg.senderFrameColor, size: 32),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                  minWidth: 60,
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
                    if (!isMe) ...[
                      GestureDetector(
                        onTap: () => context.push('/users/${msg.senderId}'),
                        child: Text(
                          msg.senderUsername.isEmpty ? msg.senderId : '@${msg.senderUsername}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFF8338EC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMessageTime(msg.createdAt),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 8.5,
                            color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 4),
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
          ],
        ],
      ),
    );
  }
}

class _PendingRequestsCard extends StatelessWidget {
  const _PendingRequestsCard({
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return StreamBuilder<List<FriendRequestWithUser>>(
      stream: socialRepository.watchIncomingRequestsWithUsers(userId),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      buildNeonIcon(context, Icons.people_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr ? 'Gelen Arkadaşlık İstekleri' : 'Incoming Friend Requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC008C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Row(
                        children: [
                          buildAvatarHelper(req.sender.avatarId, req.sender.avatarFrameColor, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.sender.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                Text(
                                  '@${req.sender.username}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Accept Button
                          ElevatedButton(
                            onPressed: () => _respond(context, req.sender.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC).withOpacity(0.15),
                              foregroundColor: const Color(0xFF00FFCC),
                              side: const BorderSide(color: Color(0xFF00FFCC), width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              tr ? 'Kabul Et' : 'Accept',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Decline Button
                          OutlinedButton(
                            onPressed: () => _respond(context, req.sender.id, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEC008C),
                              side: const BorderSide(color: Color(0xFFEC008C), width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              tr ? 'Reddet' : 'Decline',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _respond(BuildContext context, String fromUserId, bool accept) async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final confirmed = await showGothicConfirmDialog(
      context,
      title: accept
          ? (tr ? 'İsteği Kabul Et' : 'Accept Request')
          : (tr ? 'İsteği Reddet' : 'Decline Request'),
      content: accept
          ? (tr
              ? 'Arkadaşlık isteğini kabul etmek istediğinize emin misiniz?'
              : 'Are you sure you want to accept the friend request?')
          : (tr
              ? 'Arkadaşlık isteğini reddetmek istediğinize emin misiniz?'
              : 'Are you sure you want to decline the friend request?'),
    );
    if (!confirmed) return;

    await socialRepository.respondToFriendRequest(
      fromUserId: fromUserId,
      toUserId: userId,
      accept: accept,
    );
  }
}

enum _ActivityType { collectionUpdate, comment }

class _ActivityItem {
  _ActivityItem({
    required this.userId,
    required this.timestamp,
    required this.type,
    this.entry,
    this.comment,
  });

  final String userId;
  final DateTime timestamp;
  final _ActivityType type;
  final CollectionEntry? entry;
  final AppComment? comment;
}

class _SocialFeedTab extends StatelessWidget {
  const _SocialFeedTab({required this.userId});

  final String userId;

  String _timeAgo(BuildContext context, DateTime dt) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return tr ? 'Az önce' : 'Just now';
    if (diff.inMinutes < 60) return tr ? '${diff.inMinutes} dk önce' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return tr ? '${diff.inHours} saat önce' : '${diff.inHours}h ago';
    return tr ? '${diff.inDays} gün önce' : '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AppUser>>(
      stream: socialRepository.watchFriendsList(userId),
      builder: (context, friendsSnap) {
        final friends = friendsSnap.data ?? [];
        final friendUids = friends.map((u) => u.id).toSet();

        return StreamBuilder<List<AppUser>>(
          stream: socialRepository.watchFollowingList(userId),
          builder: (context, followSnap) {
            final followings = followSnap.data ?? [];
            final followingUids = followings.map((u) => u.id).toSet();

            final targetUids = {...friendUids, ...followingUids, userId};

            return StreamBuilder<List<CollectionEntry>>(
              stream: socialRepository.watchRecentPublicCollectionEntries(),
              builder: (context, collectionSnap) {
                final collections = collectionSnap.data ?? [];

                return StreamBuilder<List<AppComment>>(
                  stream: socialRepository.watchRecentComments(),
                  builder: (context, commentsSnap) {
                    final comments = commentsSnap.data ?? [];

                    final List<_ActivityItem> feedItems = [];

                    for (final entry in collections) {
                      if (targetUids.contains(entry.userId)) {
                        feedItems.add(_ActivityItem(
                          userId: entry.userId,
                          timestamp: entry.updatedAt ?? DateTime.now().subtract(const Duration(minutes: 5)),
                          type: _ActivityType.collectionUpdate,
                          entry: entry,
                        ));
                      }
                    }

                    for (final comment in comments) {
                      if (targetUids.contains(comment.userId)) {
                        feedItems.add(_ActivityItem(
                          userId: comment.userId,
                          timestamp: comment.createdAt,
                          type: _ActivityType.comment,
                          comment: comment,
                        ));
                      }
                    }

                    feedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    if (feedItems.isEmpty) {
                      return EmptyState(
                        icon: Icons.dynamic_feed_rounded,
                        title: tr ? 'Aktivite Yok' : 'No Activity',
                        body: tr
                            ? 'Takip ettiğin kişilerin veya arkadaşlarının koleksiyon güncellemeleri burada görünür.'
                            : 'Collection updates from friends and followings will appear here.',
                      );
                    }

                    return ListView.builder(
                      itemCount: feedItems.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemBuilder: (context, index) {
                        final item = feedItems[index];

                        return StreamBuilder<ProfileSetupStatus>(
                          stream: profileSetupRepository.watch(item.userId),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData) return const SizedBox.shrink();
                            final owner = userSnap.data!;
                            final username = owner.username.isNotEmpty ? '@${owner.username}' : 'Collector';

                            if (item.type == _ActivityType.collectionUpdate) {
                              final entry = item.entry!;
                              final catalogItem = findCatalogEntry(entry.itemId);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  onTap: () => context.push('/collection/${entry.id}'),
                                  leading: buildAvatarHelper(owner.avatarId, owner.avatarFrameColor, size: 36),
                                  title: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 12.5,
                                        fontFamily: 'Outfit',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '$username ',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: tr
                                              ? 'koleksiyonuna yeni bir bebek ekledi: '
                                              : 'added a new doll to their collection: ',
                                        ),
                                        TextSpan(
                                          text: entryName(context, catalogItem),
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          conditionLabel(context, entry.condition),
                                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _timeAgo(context, item.timestamp),
                                          style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                ),
                              );
                            } else {
                              final comment = item.comment!;
                              final catalogItem = findCatalogEntry(comment.targetId);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  onTap: () => context.push('/catalog/${catalogItem.id}'),
                                  leading: buildAvatarHelper(owner.avatarId, owner.avatarFrameColor, size: 36),
                                  title: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 12.5,
                                        fontFamily: 'Outfit',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '$username ',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: tr ? 'bir bebek altına yorum yaptı: ' : 'commented on a doll: ',
                                        ),
                                        TextSpan(
                                          text: entryName(context, catalogItem),
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '"${comment.text}"',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _timeAgo(context, item.timestamp),
                                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
