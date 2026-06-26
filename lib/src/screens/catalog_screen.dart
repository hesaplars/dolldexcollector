import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../collection/collection_repository.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../users/profile_setup_repository.dart';
import '../widgets/doll_widgets.dart';

class CatalogScreen extends StatefulWidget {
  final String? initialQuery;
  const CatalogScreen({this.initialQuery, super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late String _query;
  CatalogItemType? _type;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _query);
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      final newQuery = widget.initialQuery ?? '';
      _query = newQuery;
      _searchController.text = newQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      listViewKey: const PageStorageKey('catalog_scroll'),
      title: t(context, 'catalog'),
      subtitle: t(context, 'catalogSubtitle'),
      showBackButton: context.canPop(),
      child: Column(
        children: [
          SearchPanel(
            controller: _searchController,
            selectedType: _type,
            onQueryChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            onTypeChanged: (value) {
              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<User?>(
            stream: authService.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: GuestLoginBanner(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          FeaturedGrid(query: _query, type: _type),
        ],
      ),
    );
  }
}

class SearchPanel extends StatelessWidget {
  const SearchPanel({
    required this.controller,
    required this.selectedType,
    required this.onQueryChanged,
    required this.onTypeChanged,
    super.key,
  });

  final TextEditingController controller;
  final CatalogItemType? selectedType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CatalogItemType?> onTypeChanged;

  Widget _buildNeonIcon(BuildContext context, IconData icon,
      {double size = 24}) {
    return Icon(icon, size: size, color: DollDexTheme.teal);
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = isSelected ? DollDexTheme.teal : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? finalColor.withOpacity(0.15)
              : (isDark ? DollDexTheme.darkPanel : DollDexTheme.panel),
          border: Border.all(
            color: isSelected
                ? finalColor
                : (isDark ? DollDexTheme.darkLine : DollDexTheme.line),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: finalColor.withOpacity(0.25),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.white : DollDexTheme.teal)
                : (isDark ? Colors.white60 : DollDexTheme.cocoa),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? DollDexTheme.darkLine : DollDexTheme.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.09),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          _buildNeonIcon(context, Icons.search_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : DollDexTheme.ink,
                  fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: t(context, 'searchHint'),
                hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : DollDexTheme.cocoa,
                    fontSize: 13,
                    fontFamily: 'Outfit'),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showCatalogFilterSheet(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
                  width: 1.0,
                ),
                color: isDark ? DollDexTheme.darkPaper : DollDexTheme.mist,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNeonIcon(context, Icons.tune_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    selectedType == null
                        ? (tr ? 'Hepsi' : 'All')
                        : catalogTypeLabel(context, selectedType!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : DollDexTheme.cocoa,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCatalogFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(
            color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
            width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final currentUser = authService.currentUser;

        return StreamBuilder<ProfileSetupStatus>(
          stream: currentUser != null
              ? profileSetupRepository.watch(currentUser.uid)
              : const Stream.empty(),
          builder: (context, snap) {
            final isPro = snap.data?.isPro == true;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr ? 'Katalog Filtrele' : 'Filter Catalog',
                    style: TextStyle(
                      color: isDark ? Colors.white : DollDexTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        context: context,
                        isSelected: selectedType == null,
                        label: t(context, 'all'),
                        onTap: () {
                          onTypeChanged(null);
                          Navigator.of(context).pop();
                        },
                      ),
                      for (final type in CatalogItemType.values)
                        _buildFilterChip(
                          context: context,
                          isSelected: selectedType == type,
                          label: catalogTypeLabel(context, type),
                          onTap: () {
                            final isRestricted = type == CatalogItemType.set ||
                                type == CatalogItemType.pet ||
                                type == CatalogItemType.accessory;
                            if (isRestricted && !isPro) {
                              Navigator.of(context).pop();
                              showGothicConfirmDialog(
                                context,
                                title: tr
                                    ? 'Pro Filtre Özelliği'
                                    : 'Pro Filter Feature',
                                content: tr
                                    ? 'Set, Pet ve Aksesuar filtreleri DollDex Pro üyelerine özeldir. Avantajları görmek ve Pro\'ya yükseltmek ister misiniz?'
                                    : 'Set, Pet, and Accessory filters are exclusive to DollDex Pro members. Would you like to view the benefits and upgrade to Pro?',
                                confirmText:
                                    tr ? 'Pro\'ya Geç' : 'Upgrade to Pro',
                                cancelText: tr ? 'Vazgeç' : 'Cancel',
                              ).then((confirmed) {
                                if (confirmed && context.mounted) {
                                  showProSubscriptionModal(context);
                                }
                              });
                            } else {
                              onTypeChanged(type);
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class FeaturedGrid extends StatelessWidget {
  const FeaturedGrid({
    required this.query,
    required this.type,
    super.key,
  });

  final String query;
  final CatalogItemType? type;

  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;
    return StreamBuilder<ProfileSetupStatus>(
      stream: currentUser != null
          ? profileSetupRepository.watch(currentUser.uid)
          : const Stream.empty(),
      builder: (context, snap) {
        final isPro = snap.data?.isPro == true || snap.data?.role == 'admin';

        return ValueListenableBuilder<List<CatalogEntry>>(
          valueListenable: catalogEntriesNotifier,
          builder: (context, entries, _) {
            final items = filterCatalogEntries(entries, query, type);
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_rounded,
                title: t(context, 'noCatalogResults'),
                body: t(context, 'noCatalogResultsBody'),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                const columns = 4;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) => CatalogCard(
                    item: items[index],
                    isPro: isPro,
                    isSearching: query.trim().isNotEmpty,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  const CatalogCard({
    required this.item,
    required this.isPro,
    required this.isSearching,
    super.key,
  });

  final CatalogEntry item;
  final bool isPro;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final shouldBlur = isSearching && !isPro;

    Widget cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DollImage(
                  imageUrl: item.primaryImageUrl,
                  label: entryName(context, item),
                ),
              ),
              if (!shouldBlur)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go('/i/${item.id}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entryName(context, item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entrySubtitle(context, item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.0,
                  height: 1.1,
                  fontFamily: 'Outfit',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (!shouldBlur) ...[
                ValueListenableBuilder<List<CollectionEntry>>(
                  valueListenable: collectionEntriesNotifier,
                  builder: (context, collectionEntries, _) {
                    final entry = collectionEntries.firstWhere(
                      (e) => e.itemId == item.id,
                      orElse: () => const CollectionEntry(
                        id: '',
                        userId: '',
                        itemId: '',
                        status: CollectionStatus.owned,
                        condition: CollectionCondition.complete,
                        quantity: 0,
                      ),
                    );

                    final isOwned = entry.quantity > 0 &&
                        entry.status == CollectionStatus.owned;
                    final isWanted = entry.quantity > 0 &&
                        entry.status == CollectionStatus.wanted;
                    final isTrade = entry.quantity > 0 &&
                        entry.status == CollectionStatus.trade;
                    final isSelling = entry.quantity > 0 &&
                        entry.status == CollectionStatus.selling;

                    return SizedBox(
                      height: 30,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _CardActionButton(
                              tooltip: t(context, 'owned'),
                              icon: Icons.check_rounded,
                              isActive: isOwned,
                              activeColor: DollDexTheme.teal,
                              onPressed: () =>
                                  showCollectionSheet(context, item),
                            ),
                            const SizedBox(width: 4),
                            _CardActionButton(
                              tooltip: t(context, 'want'),
                              icon: isWanted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              isActive: isWanted,
                              activeColor: DollDexTheme.berry,
                              onPressed: () =>
                                  showCollectionSheet(context, item),
                            ),
                            const SizedBox(width: 4),
                            _CardActionButton(
                              tooltip: t(context, 'trade'),
                              icon: Icons.swap_horiz_rounded,
                              isActive: isTrade,
                              activeColor: Colors.deepPurpleAccent,
                              onPressed: () =>
                                  showCollectionSheet(context, item),
                            ),
                            const SizedBox(width: 4),
                            _CardActionButton(
                              tooltip: t(context, 'selling'),
                              icon: Icons.sell_outlined,
                              isActive: isSelling,
                              activeColor: DollDexTheme.amber,
                              onPressed: () =>
                                  showCollectionSheet(context, item),
                            ),
                            const SizedBox(width: 4),
                            _CardActionButton(
                              tooltip: t(context, 'report'),
                              icon: Icons.flag_outlined,
                              isNeonFlag: true,
                              onPressed: () => showReportSheet(
                                context,
                                ReportTargetType.catalogEntry,
                                item.id,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else
                const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );

    if (shouldBlur) {
      cardBody = Stack(
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
            child: cardBody,
          ),
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.35),
              child: InkWell(
                onTap: () => showProSubscriptionModal(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr
                              ? 'Görmek için\nPro olmalısınız'
                              : 'Upgrade to Pro\nto view',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      color: isPng ? Colors.transparent : null,
      elevation: isPng ? 0 : null,
      clipBehavior: Clip.antiAlias,
      child: shouldBlur
          ? cardBody
          : InkWell(
              onTap: () => context.go('/i/${item.id}'),
              child: cardBody,
            ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.isNeonFlag = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;
  final bool isNeonFlag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = activeColor ?? Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? finalColor.withOpacity(0.25)
                : (isDark
                    ? const Color(0xFF160E22).withOpacity(0.5)
                    : const Color(0xFFFAF2FF)),
            border: Border.all(
              color: isActive
                  ? finalColor
                  : (isNeonFlag
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(isDark ? 0.6 : 0.8)
                      : finalColor.withOpacity(isDark ? 0.35 : 0.6)),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: finalColor.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: SafeShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: isActive
                      ? [finalColor, Colors.white]
                      : [
                          finalColor.withOpacity(isDark ? 0.5 : 0.85),
                          (activeColor ??
                                  Theme.of(context).colorScheme.secondary)
                              .withOpacity(isDark ? 0.5 : 0.85)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Icon(
                icon,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
