import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../users/profile_setup_repository.dart';
import '../users/user_models.dart';
import '../widgets/doll_widgets.dart';
import 'collection_screen.dart';
import 'profile_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _commentController = TextEditingController();
  late Future<List<CollectionEntry>> _collectionFuture;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _collectionFuture = collectionRepository.listPublicForUser(widget.userId);
    _recordProfileVisit();
  }

  void _recordProfileVisit() async {
    final currentUserId = authService.currentUser?.uid;
    if (currentUserId == null || currentUserId == widget.userId) {
      return;
    }

    try {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final senderName = senderDoc.data()?['username'] as String? ?? authService.currentUser?.displayName ?? 'Collector';

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.userId,
        'type': 'follow',
        'title': AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Profil Ziyareti!' : 'Profile Visit!',
        'body': AppLanguageScope.languageOf(context) == AppLanguage.tr
            ? '@$senderName profilini ziyaret etti!'
            : '@$senderName visited your profile!',
        'isRead': false,
        'deepLink': '/social',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ProfileSetupStatus>(
          stream: profileSetupRepository.watch(widget.userId),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            if (profile != null && profile.username.isNotEmpty) {
              final currentPath = GoRouterState.of(context).uri.path;
              if (currentPath.startsWith('/users/')) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.replace('/u/${profile.username}');
                  }
                });
              }
            }
            final avatarId = profile?.avatarId ?? '';
            final frameColor = profile?.avatarFrameColor ?? '';

            return ListView(
              key: PageStorageKey('public_profile_${widget.userId}'),
              padding: EdgeInsets.zero,
              children: [
                // Cover Photo
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    buildCoverPhoto(context, profile?.coverId, isPro: profile?.isPro == true),
                    Positioned(
                      top: 80,
                      left: 16,
                      child: buildAvatarHelper(avatarId, frameColor, size: 76),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.4),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => _showPublicProfileActionsMenu(context, widget.userId),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      right: 16,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showStats = !_showStats;
                          });
                        },
                        icon: Icon(
                          _showStats ? Icons.insights_rounded : Icons.bar_chart_rounded,
                          color: const Color(0xFFFFCC00),
                          size: 15,
                        ),
                        label: Text(
                          AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Profil İstatistiği' : 'Profile Stats',
                          style: const TextStyle(
                            color: Color(0xFFFFCC00),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFFCC00), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: Colors.black.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile?.username.isNotEmpty == true ? '@${profile!.username}' : 'Collector',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    if (profile?.selectedBadge.isNotEmpty == true) ...[
                                      const SizedBox(width: 8),
                                      ProfileBadgeWidget(badgeId: profile!.selectedBadge),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (authService.currentUser != null && authService.currentUser!.uid != widget.userId)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StreamBuilder<bool>(
                                  stream: socialRepository.watchIsFriend(authService.currentUser!.uid, widget.userId),
                                  builder: (context, friendSnap) {
                                    final isFriend = friendSnap.data == true;
                                    if (!isFriend) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () {
                                          openDirectChatWithUser(context, widget.userId);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF00FFCC), Color(0xFF00B38F)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00FFCC).withOpacity(0.2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.chat_bubble_outline_rounded,
                                                size: 14,
                                                color: Colors.black87,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Mesaj' : 'Message',
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                StreamBuilder<bool>(
                                  stream: socialRepository.watchIsFollowing(authService.currentUser!.uid, widget.userId),
                                  builder: (context, followSnap) {
                                    final isFollowing = followSnap.data == true;
                                    return InkWell(
                                      onTap: () async {
                                        final currentUid = authService.currentUser!.uid;
                                        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                        final confirmed = await showGothicConfirmDialog(
                                          context,
                                          title: isFollowing ? (tr ? 'Takibi Bırak' : 'Unfollow') : (tr ? 'Takip Et' : 'Follow'),
                                          content: isFollowing
                                              ? (tr ? 'Bu kullanıcıyı takip etmeyi bırakmak istediğinize emin misiniz?' : 'Are you sure you want to stop following this user?')
                                              : (tr ? 'Bu kullanıcıyı takip etmek istediğinize emin misiniz?' : 'Are you sure you want to follow this user?'),
                                        );
                                        if (!confirmed) return;

                                        if (isFollowing) {
                                          await socialRepository.unfollowUser(
                                            currentUserId: currentUid,
                                            targetUserId: widget.userId,
                                          );
                                        } else {
                                          await socialRepository.followUser(
                                            currentUserId: currentUid,
                                            targetUserId: widget.userId,
                                          );
                                          try {
                                            final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                                            final senderName = senderDoc.data()?['username'] as String? ?? authService.currentUser?.displayName ?? 'Collector';
                                            await FirebaseFirestore.instance.collection('notifications').add({
                                              'userId': widget.userId,
                                              'type': 'follow',
                                              'title': AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Yeni Takipçi!' : 'New Follower!',
                                              'body': AppLanguageScope.languageOf(context) == AppLanguage.tr
                                                  ? '@$senderName seni takip etmeye başladı!'
                                                  : '@$senderName started following you!',
                                              'isRead': false,
                                              'deepLink': '/profile',
                                              'createdAt': FieldValue.serverTimestamp(),
                                            });
                                          } catch (_) {}
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: LinearGradient(
                                            colors: isFollowing
                                                ? [const Color(0xFF2C1F45), const Color(0xFF171026)]
                                                : [const Color(0xFFEC008C), const Color(0xFF8338EC)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFEC008C),
                                            width: 1.5,
                                          ),
                                          boxShadow: isFollowing
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: const Color(0xFFEC008C).withOpacity(0.3),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isFollowing
                                                  ? (AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Takibi Bırak' : 'Unfollow')
                                                  : (AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Takip Et' : 'Follow'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Connections stats row for public profile
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFriendsList(widget.userId),
                        builder: (context, friendsSnap) {
                          final friendsCount = friendsSnap.data?.length ?? 0;
                          return StreamBuilder<List<AppUser>>(
                            stream: socialRepository.watchFollowingList(widget.userId),
                            builder: (context, followingSnap) {
                              final followingCount = followingSnap.data?.length ?? 0;
                              return StreamBuilder<List<AppUser>>(
                                stream: socialRepository.watchFollowersList(widget.userId),
                                builder: (context, followersSnap) {
                                  final followersCount = followersSnap.data?.length ?? 0;
                                  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                                    child: InkWell(
                                      onTap: () => showConnectionsModal(context, widget.userId),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.4), width: 1.2),
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF171026)
                                              : const Color(0xFFFAF2FF),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Arkadaş' : 'Friends',
                                              value: friendsCount.toString(),
                                            ),
                                            Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Takip' : 'Following',
                                              value: followingCount.toString(),
                                            ),
                                            Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Takipçi' : 'Followers',
                                              value: followersCount.toString(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      if (_showStats) ...[
                        const SizedBox(height: 12),
                        CollectionAnalyticsCard(userId: widget.userId),
                      ],
                      const SizedBox(height: 12),
                      FeaturedShowcaseCard(userId: widget.userId),
                      const SizedBox(height: 12),
                      FutureBuilder<List<CollectionEntry>>(
                        future: _collectionFuture,
                        builder: (context, snapshot) {
                          final entries = snapshot.data ?? const <CollectionEntry>[];
                          if (entries.isEmpty) {
                            return EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: t(context, 'publicCollectionEmpty'),
                              body: t(context, 'publicCollectionEmptyBody'),
                            );
                          }

                          final owned = entries.where((e) => e.status == CollectionStatus.owned).toList();
                          final wanted = entries.where((e) => e.status == CollectionStatus.wanted).toList();
                          final trade = entries.where((e) => e.status == CollectionStatus.trade).toList();
                          final selling = entries.where((e) => e.status == CollectionStatus.selling).toList();

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: DefaultTabController(
                                length: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t(context, 'publicCollection'),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TabBar(
                                      isScrollable: true,
                                      tabAlignment: TabAlignment.start,
                                      indicatorColor: Theme.of(context).colorScheme.primary,
                                      labelColor: Theme.of(context).colorScheme.primary,
                                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      tabs: [
                                        Tab(text: t(context, 'owned')),
                                        Tab(text: t(context, 'wanted')),
                                        Tab(text: t(context, 'trade')),
                                        Tab(text: t(context, 'selling')),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 320,
                                      child: TabBarView(
                                        children: [
                                          CollectionCategoryTab(entries: owned, from: 'public_profile', userId: widget.userId),
                                          CollectionCategoryTab(entries: wanted, from: 'public_profile', userId: widget.userId),
                                          CollectionCategoryTab(entries: trade, from: 'public_profile', userId: widget.userId),
                                          CollectionCategoryTab(entries: selling, from: 'public_profile', userId: widget.userId),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFFEC008C),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}

void _showPublicProfileActionsMenu(BuildContext context, String targetUserId) {
  final currentUserId = authService.currentUser?.uid;
  if (currentUserId == null) return;

  showModalBottomSheet(
    context: context,
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      return SafeArea(
        child: StreamBuilder<bool>(
          stream: socialRepository.watchIsFriend(currentUserId, targetUserId),
          builder: (context, friendSnap) {
            final isFriend = friendSnap.data ?? false;
            return StreamBuilder<bool>(
              stream: socialRepository.watchHasPendingRequest(currentUserId, targetUserId),
              builder: (context, pendingSnap) {
                final hasPendingOut = pendingSnap.data ?? false;
                return StreamBuilder<bool>(
                  stream: socialRepository.watchHasPendingRequest(targetUserId, currentUserId),
                  builder: (context, pendingInSnap) {
                    final hasPendingIn = pendingInSnap.data ?? false;
                    return StreamBuilder<List<String>>(
                      stream: socialRepository.watchBlockedUsers(currentUserId),
                      builder: (context, blockedSnap) {
                        final isBlocked = (blockedSnap.data ?? []).contains(targetUserId);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFriend)
                              ListTile(
                                leading: buildNeonIcon(context, Icons.forum_rounded, size: 22),
                                title: Text(tr ? 'Mesaj Gönder' : 'Send Message'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  openDirectChatWithUser(context, targetUserId);
                                },
                              )
                            else if (hasPendingOut)
                              ListTile(
                                leading: buildNeonIcon(context, Icons.hourglass_empty_rounded, size: 22),
                                title: Text(tr ? 'Arkadaşlık İsteği Gönderildi' : 'Friend Request Sent'),
                                subtitle: Text(tr ? 'Yanıt bekleniyor...' : 'Waiting for response...'),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final confirmed = await showGothicConfirmDialog(
                                      context,
                                      title: tr ? 'İsteği İptal Et' : 'Cancel Request',
                                      content: tr
                                          ? 'Arkadaşlık isteğini iptal etmek istediğinize emin misiniz?'
                                          : 'Are you sure you want to cancel the friend request?',
                                    );
                                    if (!confirmed) return;
                                    await socialRepository.removeFriend(
                                      userA: currentUserId,
                                      userB: targetUserId,
                                    );
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                  child: Text(t(context, 'cancel')),
                                ),
                              )
                            else if (hasPendingIn)
                              ListTile(
                                leading: buildNeonIcon(context, Icons.person_add_alt_1_rounded, size: 22),
                                title: Text(tr ? 'Arkadaşlık İsteğini Kabul Et' : 'Accept Friend Request'),
                                onTap: () async {
                                  final confirmed = await showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'İsteği Kabul Et' : 'Accept Request',
                                    content: tr
                                        ? 'Arkadaşlık isteğini kabul etmek istediğinize emin misiniz?'
                                        : 'Are you sure you want to accept the friend request?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.respondToFriendRequest(
                                    fromUserId: targetUserId,
                                    toUserId: currentUserId,
                                    accept: true,
                                  );
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                              )
                            else
                              ListTile(
                                leading: buildNeonIcon(context, Icons.person_add_alt_1_outlined, size: 22),
                                title: Text(t(context, 'sendFriendRequest')),
                                onTap: () async {
                                  final confirmed = await showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'Arkadaş Ekle' : 'Add Friend',
                                    content: tr
                                        ? 'Bu kullanıcıya arkadaşlık isteği göndermek istiyor musunuz?'
                                        : 'Do you want to send a friend request to this user?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.sendFriendRequest(
                                    fromUserId: currentUserId,
                                    toUserId: targetUserId,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(t(context, 'friendRequestSent'))),
                                    );
                                  }
                                },
                              ),
                            if (isFriend)
                              ListTile(
                                leading: buildNeonIcon(context, Icons.person_remove_outlined, size: 22),
                                title: Text(tr ? 'Arkadaşlıktan Çıkar' : 'Unfriend'),
                                onTap: () async {
                                  final confirmed = await showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'Arkadaşlıktan Çıkar' : 'Unfriend',
                                    content: tr
                                        ? 'Bu kullanıcıya arkadaşlarınızdan çıkarmak istediğinize emin misiniz?'
                                        : 'Are you sure you want to remove this user from friends?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.removeFriend(
                                    userA: currentUserId,
                                    userB: targetUserId,
                                  );
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                              ),
                            ListTile(
                              leading: buildNeonIcon(
                                context,
                                isBlocked ? Icons.block_flipped : Icons.block,
                                size: 22,
                              ),
                              title: Text(
                                isBlocked
                                    ? (tr ? 'Engeli Kaldır' : 'Unblock User')
                                    : (tr ? 'Engelle' : 'Block User'),
                              ),
                              onTap: () async {
                                final confirmed = await showGothicConfirmDialog(
                                  context,
                                  title: isBlocked
                                      ? (tr ? 'Engeli Kaldır' : 'Unblock User')
                                      : (tr ? 'Kullanıcıyı Engelle' : 'Block User'),
                                  content: isBlocked
                                      ? (tr ? 'Bu kullanıcının engelini kaldırmak istediğinize emin misiniz?' : 'Are you sure you want to unblock this user?')
                                      : (tr ? 'Bu kullanıcıyı engellemek istediğinize emin misiniz?' : 'Are you sure you want to block this user?'),
                                );
                                if (!confirmed) return;

                                if (isBlocked) {
                                  await socialRepository.unblockUser(
                                    blockerId: currentUserId,
                                    blockedId: targetUserId,
                                  );
                                } else {
                                  await socialRepository.blockUser(
                                    blockerId: currentUserId,
                                    blockedId: targetUserId,
                                  );
                                }
                                if (context.mounted) Navigator.of(context).pop();
                              },
                            ),
                            ListTile(
                              leading: buildNeonFlagIcon(context, size: 22),
                              title: Text(t(context, 'report')),
                              onTap: () {
                                Navigator.of(context).pop();
                                showReportSheet(
                                  context,
                                  ReportTargetType.profile,
                                  targetUserId,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      );
    },
  );
}
