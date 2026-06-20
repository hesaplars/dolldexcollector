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

    return PageShell(
      title: entryName(context, item),
      subtitle: entrySubtitle(context, item),
      child: LayoutBuilder(
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
                        item.imageUrls.isNotEmpty ? item.imageUrls : [item.primaryImageUrl],
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
                    Expanded(flex: 2, child: imagePanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: infoPanel),
                  ],
                ),
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
              imagePanel,
              const SizedBox(height: 16),
              infoPanel,
              const SizedBox(height: 16),
              ValueListenableBuilder<Map<String, List<AppComment>>>(
                valueListenable: commentsNotifier,
                builder: (context, commentsByTarget, _) {
                  return _CommentsPanel(
                    controller: _commentController,
                    comments: commentsByTarget[item.id] ?? const <AppComment>[],
                    onSubmit: _addComment,
                  );
                },
              ),
            ],
          );
        },
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
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
                    leading: buildAvatarHelper(
                      comment.senderAvatarId,
                      comment.senderFrameColor,
                      size: 38,
                    ),
                    title: Text(
                      comment.senderUsername.isNotEmpty
                          ? comment.senderUsername
                          : 'Collector',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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
