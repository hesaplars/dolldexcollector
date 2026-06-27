import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';
import '../catalog/catalog_models.dart';
import '../comments/comment_models.dart';
import '../users/profile_setup_repository.dart';
import '../users/user_models.dart';

enum ActivityType { collectionUpdate, comment }

class ActivityItem {
  ActivityItem({
    required this.userId,
    required this.timestamp,
    required this.type,
    this.entry,
    this.comment,
  });

  final String userId;
  final DateTime timestamp;
  final ActivityType type;
  final CollectionEntry? entry;
  final AppComment? comment;
}

class SocialFeedTab extends StatelessWidget {
  const SocialFeedTab({
    required this.userId,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.onNavigate,
    super.key,
  });

  final String userId;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final void Function(String route)? onNavigate;

  String _timeAgo(BuildContext context, DateTime dt) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return tr ? 'Az önce' : 'Just now';
    if (diff.inMinutes < 60)
      return tr ? '${diff.inMinutes} dk önce' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24)
      return tr ? '${diff.inHours} saat önce' : '${diff.inHours}h ago';
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
                    if ((friendsSnap.connectionState == ConnectionState.waiting && !friendsSnap.hasData) ||
                        (followSnap.connectionState == ConnectionState.waiting && !followSnap.hasData) ||
                        (collectionSnap.connectionState == ConnectionState.waiting && !collectionSnap.hasData) ||
                        (commentsSnap.connectionState == ConnectionState.waiting && !commentsSnap.hasData)) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final comments = commentsSnap.data ?? [];
                    final List<ActivityItem> feedItems = [];

                    for (final entry in collections) {
                      if (targetUids.contains(entry.userId)) {
                        feedItems.add(ActivityItem(
                          userId: entry.userId,
                          timestamp: entry.updatedAt ??
                              DateTime.now()
                                  .subtract(const Duration(minutes: 5)),
                          type: ActivityType.collectionUpdate,
                          entry: entry,
                        ));
                      }
                    }

                    for (final comment in comments) {
                      if (targetUids.contains(comment.userId)) {
                        feedItems.add(ActivityItem(
                          userId: comment.userId,
                          timestamp: comment.createdAt,
                          type: ActivityType.comment,
                          comment: comment,
                        ));
                      }
                    }

                    feedItems
                        .sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
                      key: const PageStorageKey('activity_feed_scroll_key'),
                      controller: scrollController,
                      shrinkWrap: shrinkWrap,
                      physics: physics ?? const AlwaysScrollableScrollPhysics(),
                      itemCount: feedItems.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemBuilder: (context, index) {
                        final item = feedItems[index];

                        return StreamBuilder<ProfileSetupStatus>(
                          stream: profileSetupRepository.watch(item.userId),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData)
                              return const SizedBox.shrink();
                            final owner = userSnap.data!;
                            final username = owner.username.isNotEmpty
                                ? '@${owner.username}'
                                : 'Collector';

                            if (item.type == ActivityType.collectionUpdate) {
                              final entry = item.entry!;
                              final catalogItem =
                                  findCatalogEntry(entry.itemId);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  onTap: () {
                                    final route = '/c/${entry.id}?from=/social';
                                    if (onNavigate != null) {
                                      onNavigate!(route);
                                    } else {
                                      context.push(route);
                                    }
                                  },
                                  leading: GestureDetector(
                                    onTap: () {
                                      final username = owner.username.trim();
                                      final route = username.isNotEmpty
                                          ? '/u/$username?from=/social'
                                          : '/users/${owner.userId}?from=/social';
                                      if (onNavigate != null) {
                                        onNavigate!(route);
                                      } else {
                                        context.push(route);
                                      }
                                    },
                                    child: buildAvatarHelper(context,
                                        owner.avatarId, owner.avatarFrameColor,
                                        size: 36),
                                  ),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (owner.selectedBadge.isNotEmpty) ...[
                                        ProfileBadgeWidget(
                                            badgeId: owner.selectedBadge,
                                            size: 7),
                                        const SizedBox(height: 2),
                                      ],
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 12.5,
                                            fontFamily: 'Outfit',
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '$username ',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  final username =
                                                      owner.username.trim();
                                                  final route = username
                                                          .isNotEmpty
                                                      ? '/u/$username?from=/social'
                                                      : '/users/${owner.userId}?from=/social';
                                                  if (onNavigate != null) {
                                                    onNavigate!(route);
                                                  } else {
                                                    context.push(route);
                                                  }
                                                },
                                            ),
                                            TextSpan(
                                              text: tr
                                                  ? 'koleksiyonuna yeni bir bebek ekledi: '
                                                  : 'added a new doll to their collection: ',
                                            ),
                                            TextSpan(
                                              text: entryName(
                                                  context, catalogItem),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          conditionLabel(
                                              context, entry.condition),
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              fontStyle: FontStyle.italic),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _timeAgo(context, item.timestamp),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18),
                                ),
                              );
                            } else {
                              final comment = item.comment!;
                              return CommentActivityCard(
                                comment: comment,
                                owner: owner,
                                timestamp: item.timestamp,
                                username: username,
                                isDark: isDark,
                                tr: tr,
                                timeAgo: _timeAgo(context, item.timestamp),
                                onNavigate: onNavigate,
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

class CommentActivityCard extends StatelessWidget {
  const CommentActivityCard({
    required this.comment,
    required this.owner,
    required this.timestamp,
    required this.username,
    required this.isDark,
    required this.tr,
    required this.timeAgo,
    this.onNavigate,
    super.key,
  });

  final AppComment comment;
  final ProfileSetupStatus owner;
  final DateTime timestamp;
  final String username;
  final bool isDark;
  final bool tr;
  final String timeAgo;
  final void Function(String route)? onNavigate;

  @override
  Widget build(BuildContext context) {
    if (comment.sharedCatalogEntryId.isNotEmpty) {
      final catalogItem = findCatalogEntry(comment.sharedCatalogEntryId);
      return _buildCard(context, catalogItem);
    }

    return FutureBuilder<CollectionEntry?>(
      future: collectionRepository.fetch(comment.targetId),
      builder: (context, snapshot) {
        final entry = snapshot.data;
        final catalogItem = entry != null
            ? findCatalogEntry(entry.itemId)
            : findCatalogEntry('missing');
        return _buildCard(context, catalogItem);
      },
    );
  }

  Widget _buildCard(BuildContext context, CatalogEntry catalogItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          final route = '/i/${catalogItem.id}?from=/social';
          if (onNavigate != null) {
            onNavigate!(route);
          } else {
            context.push(route);
          }
        },
        leading: GestureDetector(
          onTap: () {
            final username = owner.username.trim();
            final route = username.isNotEmpty
                ? '/u/$username?from=/social'
                : '/users/${owner.userId}?from=/social';
            if (onNavigate != null) {
              onNavigate!(route);
            } else {
              context.push(route);
            }
          },
          child: buildAvatarHelper(
              context, owner.avatarId, owner.avatarFrameColor,
              size: 36),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (owner.selectedBadge.isNotEmpty) ...[
              ProfileBadgeWidget(badgeId: owner.selectedBadge, size: 7),
              const SizedBox(height: 2),
            ],
            RichText(
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
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        final username = owner.username.trim();
                        final route = username.isNotEmpty
                            ? '/u/$username?from=/social'
                            : '/users/${owner.userId}?from=/social';
                        if (onNavigate != null) {
                          onNavigate!(route);
                        } else {
                          context.push(route);
                        }
                      },
                  ),
                  TextSpan(
                    text: tr
                        ? 'bir bebek altına yorum yaptı: '
                        : 'commented on a doll: ',
                  ),
                  TextSpan(
                    text: entryName(context, catalogItem),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${comment.text}"',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 10,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    );
  }
}
