import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../collection/collection_repository.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../notifications/notification_models.dart';
import '../widgets/doll_widgets.dart';
import '../users/profile_setup_repository.dart';
import '../collection/collection_action_sheet.dart';
import '../comments/comment_models.dart';

class UserCollectionEntryDetailScreen extends StatefulWidget {
  const UserCollectionEntryDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  State<UserCollectionEntryDetailScreen> createState() =>
      _UserCollectionEntryDetailScreenState();
}

class _UserCollectionEntryDetailScreenState
    extends State<UserCollectionEntryDetailScreen> {
  final _commentController = TextEditingController();
  Future<CollectionEntry?>? _entryFuture;

  @override
  void initState() {
    super.initState();
    _entryFuture = collectionRepository.fetch(widget.entryId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showEditCollectionSheet(BuildContext context, CatalogEntry item, CollectionEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return CollectionActionSheet(
          item: item,
          initialEntry: entry,
          onSave: (draft) async {
            final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
            final confirmed = await showGothicConfirmDialog(
              context,
              title: tr ? 'Koleksiyonu Güncelle' : 'Update Collection',
              content: tr
                  ? '${entryName(context, item)} öğesini koleksiyonunuza kaydetmek istiyor musunuz?'
                  : 'Do you want to save ${entryName(context, item)} to your collection?',
            );
            if (!confirmed) return false;

            final userId = authService.currentUser?.uid ?? 'local-user';
            final updatedEntry = CollectionEntry(
              id: entry.id,
              userId: userId,
              itemId: draft.itemId,
              status: draft.status,
              condition: draft.condition,
              quantity: draft.quantity,
              notes: draft.notes,
              isPublic: draft.isPublic,
            );
            collectionEntriesNotifier.value = [
              updatedEntry,
              ...collectionEntriesNotifier.value.where(
                (existing) => existing.id != entry.id,
              ),
            ];
            collectionRepository.save(updatedEntry).catchError((Object error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Koleksiyon kaydı başarısız: $error')),
                );
              }
            });
            addAppNotification(
              '${entryName(context, item)} ${t(context, 'collectionUpdated')}',
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${entryName(context, item)} ${t(context, 'markedAs')} '
                    '${collectionStatusLabel(context, draft.status)}.',
                  ),
                ),
              );
            }
            if (mounted) {
              setState(() {
                _entryFuture = collectionRepository.fetch(widget.entryId);
              });
            }
            return true;
          },
        );
      },
    );
  }

  IconData _typeIcon(CatalogItemType type) {
    return switch (type) {
      CatalogItemType.character => Icons.face_retouching_natural_rounded,
      CatalogItemType.doll => Icons.face_3_outlined,
      CatalogItemType.set => Icons.inventory_2_outlined,
      CatalogItemType.pet => Icons.pets_rounded,
      CatalogItemType.accessory => Icons.earbuds_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      title: tr ? 'Koleksiyon Parçası Detayı' : 'Collection Item Detail',
      subtitle: tr ? 'Koleksiyoner rafındaki detaylı bilgiler' : 'Detailed information on collector shelf',
      child: FutureBuilder<CollectionEntry?>(
        future: _entryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Hata / Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
          final entry = snapshot.data;
          if (entry == null) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: t(context, 'entryNotFound'),
              body: t(context, 'entryNotFoundBody'),
            );
          }

          final item = findCatalogEntry(entry.itemId);

          final isPng = item.primaryImageUrl.toLowerCase().contains('.png');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: isPng ? Colors.transparent : null,
                elevation: isPng ? 0 : null,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: item.imageUrls.length > 1
                              ? PageView.builder(
                                  itemCount: item.imageUrls.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => showPhotoGalleryDialog(context, item.imageUrls, index),
                                      child: DollImage(
                                        imageUrl: item.imageUrls[index],
                                        label: entryName(context, item),
                                      ),
                                    );
                                  },
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
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder<int>(
                                stream: socialRepository.watchLikesCount('collectionEntry', entry.id),
                                builder: (context, likesSnap) {
                                  final count = likesSnap.data ?? 0;
                                  return StreamBuilder<bool>(
                                    stream: currentUser != null
                                        ? socialRepository.watchIsLiked(currentUser.uid, 'collectionEntry', entry.id)
                                        : Stream.value(false),
                                    builder: (context, isLikedSnap) {
                                      final isLiked = isLikedSnap.data ?? false;
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          buildGothicNeonIconButton(
                                            context: context,
                                            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 16,
                                            padding: const EdgeInsets.all(8),
                                            onPressed: currentUser == null
                                                ? null
                                                : () async {
                                                    if (isLiked) {
                                                      await socialRepository.unlikeTarget(
                                                        userId: currentUser.uid,
                                                        targetType: 'collectionEntry',
                                                        targetId: entry.id,
                                                      );
                                                    } else {
                                                      await socialRepository.likeTarget(
                                                        userId: currentUser.uid,
                                                        targetType: 'collectionEntry',
                                                        targetId: entry.id,
                                                      );
                                                    }
                                                  },
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFFEC008C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<List<AppComment>>(
                                stream: commentRepository.watchForTarget(
                                  targetType: 'collectionEntry',
                                  targetId: entry.id,
                                ),
                                builder: (context, commentsSnap) {
                                  final count = commentsSnap.data?.length ?? 0;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      buildGothicNeonIconButton(
                                        context: context,
                                        icon: Icons.mode_comment_outlined,
                                        size: 16,
                                        padding: const EdgeInsets.all(8),
                                        activeColor: const Color(0xFF00FFCC),
                                        onPressed: () => showCommentsSheet(context, entry.id, catalogEntryId: entry.itemId),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFFEC008C),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          shadows: isDark ? [
                                            const Shadow(color: Colors.black87, blurRadius: 4),
                                          ] : null,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entryName(context, item),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                              buildNeonIcon(context, _typeIcon(item.type), size: 24),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entrySubtitle(context, item),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (item.year != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${tr ? 'Yıl' : 'Year'}: ${item.year}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr ? 'Koleksiyon Durumu' : 'Collection Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                           ),
                          if ((currentUser != null && entry.userId == currentUser.uid) || (entry.userId == 'local-user'))
                            StreamBuilder<ProfileSetupStatus>(
                              stream: profileSetupRepository.watch(currentUser?.uid ?? 'local-user'),
                              builder: (context, userSnap) {
                                final isFeatured = userSnap.data?.featuredEntryIds.contains(entry.id) ?? false;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: currentUser == null
                                          ? null
                                          : () async {
                                              final currentFeatured = List<String>.from(userSnap.data?.featuredEntryIds ?? []);
                                              if (isFeatured) {
                                                currentFeatured.remove(entry.id);
                                              } else {
                                                if (currentFeatured.length >= 5) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        tr
                                                            ? 'En fazla 5 bebek vitrine eklenebilir!'
                                                            : 'Max 5 dolls can be featured!',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                currentFeatured.add(entry.id);
                                              }
                                              await profileSetupRepository.updateFeaturedEntries(
                                                userId: currentUser.uid,
                                                entryIds: currentFeatured,
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isFeatured
                                                        ? (tr ? 'Vitrinden kaldırıldı.' : 'Removed from showcase.')
                                                        : (tr ? 'Vitrine eklendi!' : 'Added to showcase!'),
                                                  ),
                                                ),
                                              );
                                            },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        side: const BorderSide(color: Color(0xFFFFCC00), width: 1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        backgroundColor: const Color(0xFFFFCC00).withOpacity(0.08),
                                      ),
                                      child: Text(
                                        isFeatured
                                            ? (tr ? 'Vitrinden Kaldır' : 'Remove from Showcase')
                                            : (tr ? 'Vitrine Ekle' : 'Add to Showcase'),
                                        style: const TextStyle(
                                          color: Color(0xFFFFCC00),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    buildGothicNeonIconButton(
                                      context: context,
                                      icon: Icons.edit_rounded,
                                      size: 16,
                                      padding: const EdgeInsets.all(8),
                                      activeColor: const Color(0xFF00FFCC),
                                      onPressed: () {
                                        _showEditCollectionSheet(context, item, entry);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.inventory_2_outlined,
                              label: tr ? 'Adet' : 'Qty',
                              value: '${entry.quantity}',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.fact_check_outlined,
                              label: tr ? 'Durum' : 'Cond.',
                              value: conditionLabel(context, entry.condition),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.bookmark_outline_rounded,
                              label: tr ? 'Statü' : 'Status',
                              value: collectionStatusLabel(context, entry.status),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: entry.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                              label: tr ? 'Erişim' : 'Access',
                              value: entry.isPublic ? (tr ? 'Açık' : 'Public') : (tr ? 'Gizli' : 'Private'),
                            ),
                          ),
                        ],
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          tr ? 'Koleksiyoner Notları' : 'Collector Notes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.notes,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<ProfileSetupStatus>(
                stream: profileSetupRepository.watch(entry.userId),
                builder: (context, ownerSnap) {
                  if (!ownerSnap.hasData) {
                    return const SizedBox();
                  }
                  final owner = ownerSnap.data!;
                  return Card(
                    child: ListTile(
                      leading: buildAvatarHelper(owner.avatarId, owner.avatarFrameColor, size: 40),
                      title: Text(owner.username.isEmpty ? 'Collector' : '@${owner.username}'),
                      subtitle: Text(tr ? 'Koleksiyoncu profili için tıklayın' : 'Tap to view collector profile'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/users/${entry.userId}'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyReportsCard extends StatelessWidget {
  const MyReportsCard({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return StreamBuilder<List<UserReport>>(
      stream: reportService.watchReportsForUser(userId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr ? 'Raporlarım' : 'My Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final report = list[index];
                    return FutureBuilder<String>(
                      future: resolveReportTargetText(report),
                      builder: (context, targetSnap) {
                        final targetText = targetSnap.data ?? report.targetId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: buildNeonFlagIcon(context, size: 20),
                          title: Text(
                            '${reportReasonLabel(context, report.reason)}: $targetText',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            report.details.isNotEmpty ? report.details : (tr ? 'Detay yok' : 'No details'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(report.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _statusColor(report.status), width: 1),
                            ),
                            child: Text(
                              reportStatusLabel(context, report.status),
                              style: TextStyle(
                                color: _statusColor(report.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
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
  }

  Color _statusColor(ReportStatus status) {
    return switch (status) {
      ReportStatus.open => Colors.orange,
      ReportStatus.reviewing => Colors.purpleAccent,
      ReportStatus.resolved => Colors.green,
      ReportStatus.dismissed => Colors.grey,
    };
  }
}
