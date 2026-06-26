import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../comments/comment_models.dart';
import '../collection/collection_repository.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../widgets/doll_widgets.dart';
import '../users/profile_setup_repository.dart';

class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    required this.item,
    super.key,
  });

  final CatalogEntry item;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  final _commentController = TextEditingController();
  StreamSubscription<List<AppComment>>? _commentsSubscription;

  @override
  void initState() {
    super.initState();
    _watchComments();
  }

  @override
  void didUpdateWidget(CatalogDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _watchComments();
    }
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _watchComments() {
    _commentsSubscription?.cancel();
    _commentsSubscription = commentRepository
        .watchForTarget(targetType: 'catalogEntry', targetId: widget.item.id)
        .listen((comments) {
      commentsNotifier.value = {
        ...commentsNotifier.value,
        widget.item.id: comments,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final uri = GoRouterState.of(context).uri;
    final from = uri.queryParameters['from'];
    final currentPath = uri.path;

    if (currentPath.startsWith('/catalog/')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.replace('/i/${widget.item.id}');
        }
      });
    }

    return PageShell(
      title: entryName(context, item),
      subtitle: entrySubtitle(context, item),
      showBackButton: true,
      onBack: () {
        if (from == 'admin_catalog_modal') {
          context.go('/admin?open_catalog_modal=true');
        } else if (context.canPop()) {
          context.pop();
        } else {
          if (from == 'collection') {
            context.go('/collection');
          } else if (from == 'profile') {
            context.go('/profile');
          } else if (from == '/social' || from == 'social') {
            context.go('/social');
          } else {
            context.go('/');
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.series != null && item.series!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ActionChip(
                avatar: Icon(
                  Icons.folder_special_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  item.series!,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.08),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  context.push('/?q=${Uri.encodeComponent(item.series!)}');
                },
              ),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 820;
              final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
              final imagePanel = Card(
                color: isPng ? Colors.transparent : null,
                elevation: isPng ? 0 : null,
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: item.imageUrls.length > 1
                      ? GothicImageSlider(
                          imageUrls: item.imageUrls,
                          label: entryName(context, item),
                        )
                      : GestureDetector(
                          onTap: () => showPhotoGalleryDialog(
                            context,
                            item.imageUrls.isNotEmpty
                                ? item.imageUrls
                                : [item.primaryImageUrl],
                            0,
                          ),
                          child: DollImage(
                            imageUrl: item.primaryImageUrl,
                            label: entryName(context, item),
                          ),
                        ),
                ),
              );
              final infoPanel = _CatalogInfoPanel(
                item: item,
                onAdd: () => showCollectionSheet(context, item),
                onReport: () => showReportSheet(
                  context,
                  ReportTargetType.catalogEntry,
                  item.id,
                ),
              );

              if (wide) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: imagePanel,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: infoPanel),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SetPartsWidget(item: item),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<Map<String, List<AppComment>>>(
                      valueListenable: commentsNotifier,
                      builder: (context, commentsByTarget, _) {
                        return _CommentsPanel(
                          controller: _commentController,
                          comments:
                              commentsByTarget[item.id] ?? const <AppComment>[],
                          onSubmit: _addComment,
                        );
                      },
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: imagePanel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  infoPanel,
                  const SizedBox(height: 16),
                  SetPartsWidget(item: item),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<Map<String, List<AppComment>>>(
                    valueListenable: commentsNotifier,
                    builder: (context, commentsByTarget, _) {
                      return _CommentsPanel(
                        controller: _commentController,
                        comments:
                            commentsByTarget[item.id] ?? const <AppComment>[],
                        onSubmit: _addComment,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final itemId = widget.item.id;
    final user = authService.currentUser;
    String senderUsername = 'Collector';
    String senderAvatarId = '';
    String senderFrameColor = '';
    if (user != null) {
      senderUsername = user.displayName ?? 'Collector';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final customUsername = data?['username'] as String? ?? '';
        if (customUsername.isNotEmpty) {
          senderUsername = '@$customUsername';
        }
        senderAvatarId = data?['avatarId'] as String? ?? '';
        senderFrameColor = data?['avatarFrameColor'] as String? ?? '';
      } catch (_) {}
    }

    final comment = AppComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      targetType: 'catalogEntry',
      targetId: itemId,
      userId: user?.uid ?? 'local-user',
      text: text,
      senderUsername: senderUsername,
      senderAvatarId: senderAvatarId,
      senderFrameColor: senderFrameColor,
    );
    final current = commentsNotifier.value[itemId] ?? const <AppComment>[];
    commentsNotifier.value = {
      ...commentsNotifier.value,
      itemId: [comment, ...current],
    };
    commentRepository.add(comment).catchError((_) {});
    addAppNotification(
      '${entryName(context, widget.item)}: ${t(context, 'commentAdded')}',
    );
    _commentController.clear();
  }
}

class _CatalogInfoPanel extends StatelessWidget {
  const _CatalogInfoPanel({
    required this.item,
    required this.onAdd,
    required this.onReport,
  });

  final CatalogEntry item;
  final VoidCallback onAdd;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(catalogTypeLabel(context, item.type))),
                if (item.year != null) Chip(label: Text('${item.year}')),
                for (final tag in item.tags) Chip(label: Text(tag)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.description.isEmpty
                  ? t(context, 'wikiPlaceholder')
                  : entryDescription(context, item),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(t(context, 'addToCollection')),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: t(context, 'report'),
                  child: buildGothicNeonIconButton(
                    context: context,
                    icon: Icons.flag_outlined,
                    onPressed: onReport,
                    size: 20,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.controller,
    required this.comments,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final List<AppComment> comments;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'comments'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: t(context, 'commentHint'),
                hintStyle: const TextStyle(fontFamily: 'Outfit'),
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_outlined),
              label: Text(t(context, 'postComment')),
            ),
            const SizedBox(height: 14),
            for (final comment in comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DollDexTheme.darkLine
                          : DollDexTheme.line,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (comment.senderUsername.isNotEmpty) {
                          final uName =
                              comment.senderUsername.replaceAll('@', '');
                          context.go('/u/$uName');
                        } else {
                          context.go('/users/${comment.userId}');
                        }
                      },
                      child: buildAvatarHelper(
                        context,
                        comment.senderAvatarId,
                        comment.senderFrameColor,
                        size: 38,
                      ),
                    ),
                    title: StreamBuilder<ProfileSetupStatus>(
                      stream: profileSetupRepository.watch(comment.userId),
                      builder: (context, snapshot) {
                        final badge = snapshot.data?.selectedBadge ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badge.isNotEmpty) ...[
                              ProfileBadgeWidget(badgeId: badge, size: 7),
                              const SizedBox(height: 2),
                            ],
                            GestureDetector(
                              onTap: () {
                                if (comment.senderUsername.isNotEmpty) {
                                  final uName = comment.senderUsername
                                      .replaceAll('@', '');
                                  context.go('/u/$uName');
                                } else {
                                  context.go('/users/${comment.userId}');
                                }
                              },
                              child: Text(
                                comment.senderUsername.isNotEmpty
                                    ? comment.senderUsername
                                    : 'Collector',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    subtitle: Text(
                      comment.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      tooltip: t(context, 'reportComment'),
                      onPressed: () => showReportSheet(
                        context,
                        ReportTargetType.comment,
                        comment.id,
                      ),
                      icon: buildNeonFlagIcon(context, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E152C) : DollDexTheme.mist,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildGothicNeonIconButton(
            context: context,
            icon: Icons.image_outlined,
            size: 36,
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }
}

class SetPartsWidget extends StatelessWidget {
  const SetPartsWidget({required this.item, super.key});
  final CatalogEntry item;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<List<CatalogEntry>>(
      valueListenable: catalogEntriesNotifier,
      builder: (context, allCatalog, _) {
        final children =
            allCatalog.where((c) => c.parentId == item.id).toList();
        if (children.isEmpty) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<List<CollectionEntry>>(
          valueListenable: collectionEntriesNotifier,
          builder: (context, userColl, _) {
            final ownedChildren = children.where((child) {
              final entry = userColl.cast<CollectionEntry?>().firstWhere(
                    (e) => e?.itemId == child.id,
                    orElse: () => null,
                  );
              return entry != null && entry.status == CollectionStatus.owned;
            }).toList();

            final totalCount = children.length;
            final ownedCount = ownedChildren.length;
            final progress = totalCount > 0 ? ownedCount / totalCount : 0.0;
            final isSetComplete = ownedCount == totalCount;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSetComplete
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.2),
                  width: isSetComplete ? 2.0 : 1.0,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSetComplete
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr
                                    ? 'Set Parçaları & Aksesuarlar'
                                    : 'Set Parts & Accessories',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr
                                    ? 'Bu bebeğe ait diğer aksesuarları ve parçaları topla.'
                                    : 'Collect other accessories and parts belonging to this doll.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSetComplete)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: colorScheme.primary, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded,
                                    color: colorScheme.primary, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  tr ? 'Set Tamamlandı!' : 'Set Complete!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  isDark ? Colors.white10 : Colors.black12,
                              color: isSetComplete
                                  ? colorScheme.primary
                                  : colorScheme.secondary,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$ownedCount/$totalCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: children.length,
                      itemBuilder: (context, index) {
                        final child = children[index];
                        final collEntry =
                            userColl.cast<CollectionEntry?>().firstWhere(
                                  (e) => e?.itemId == child.id,
                                  orElse: () => null,
                                );

                        Widget trailing;
                        if (collEntry == null) {
                          trailing = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 20),
                                onPressed: () =>
                                    showCollectionSheet(context, child),
                                tooltip: tr
                                    ? 'Koleksiyona Ekle'
                                    : 'Add to Collection',
                              ),
                            ],
                          );
                        } else if (collEntry.status == CollectionStatus.owned) {
                          trailing = Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  tr ? 'Koleksiyonunda' : 'In Collection',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (collEntry.status ==
                            CollectionStatus.wanted) {
                          trailing = Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.pink.withValues(alpha: 0.3),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    color: Colors.pink, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  tr ? 'İstek Listesinde' : 'Wishlist',
                                  style: const TextStyle(
                                    color: Colors.pink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          trailing = Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                  width: 1),
                            ),
                            child: Text(
                              collEntry.status.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: DollImage(
                                imageUrl: child.primaryImageUrl,
                                label: entryName(context, child),
                              ),
                            ),
                          ),
                          title: Text(
                            entryName(context, child),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            catalogTypeLabel(context, child.type),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          trailing: trailing,
                          onTap: () {
                            context.go('/i/${child.id}');
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
