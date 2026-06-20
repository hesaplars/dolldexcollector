import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../collection/collection_repository.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../widgets/doll_widgets.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';
  CatalogItemType? _type;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: t(context, 'catalog'),
      subtitle: t(context, 'catalogSubtitle'),
      child: Column(
        children: [
          SearchPanel(
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
    required this.selectedType,
    required this.onQueryChanged,
    required this.onTypeChanged,
    super.key,
  });

  final CatalogItemType? selectedType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CatalogItemType?> onTypeChanged;

  Widget _buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
    return SafeShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = isSelected ? const Color(0xFFEC008C) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? finalColor.withOpacity(0.15)
              : (isDark ? const Color(0xFF160E22) : Colors.white),
          border: Border.all(
            color: isSelected
                ? finalColor
                : (isDark ? const Color(0xFFEC008C).withOpacity(0.2) : Colors.black12),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: finalColor.withOpacity(0.25),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFFEC008C))
                : (isDark ? Colors.white60 : Colors.black87),
            fontSize: 12,
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

    return GothicIvyContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: t(context, 'searchHint'),
                hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14, fontFamily: 'Outfit'),
                prefixIcon: _buildNeonIcon(context, Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showCatalogFilterSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEC008C).withOpacity(isDark ? 0.5 : 0.25),
                  width: 1.2,
                ),
                color: isDark ? const Color(0xFF160E22) : Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNeonIcon(context, Icons.tune_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    selectedType == null ? (tr ? 'Hepsi' : 'All') : catalogTypeLabel(context, selectedType!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFFEC008C),
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
      backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        return GothicIvyContainer(
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr ? 'Katalog Filtrele' : 'Filter Catalog',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
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
                        onTypeChanged(type);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
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
            const columns = 3;

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
              itemBuilder: (context, index) => CatalogCard(item: items[index]),
            );
          },
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  const CatalogCard({required this.item, super.key});

  final CatalogEntry item;

  @override
  Widget build(BuildContext context) {
    final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
    return Card(
      color: isPng ? Colors.transparent : null,
      elevation: isPng ? 0 : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catalog/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DollImage(
                imageUrl: item.primaryImageUrl,
                label: entryName(context, item),
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

                      final isOwned = entry.quantity > 0 && entry.status == CollectionStatus.owned;
                      final isWanted = entry.quantity > 0 && entry.status == CollectionStatus.wanted;
                      final isTrade = entry.quantity > 0 && entry.status == CollectionStatus.trade;
                      final isSelling = entry.quantity > 0 && entry.status == CollectionStatus.selling;

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
                                onPressed: () => showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'want'),
                                icon: isWanted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                isActive: isWanted,
                                activeColor: DollDexTheme.berry,
                                onPressed: () => showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'trade'),
                                icon: Icons.swap_horiz_rounded,
                                isActive: isTrade,
                                activeColor: Colors.deepPurpleAccent,
                                onPressed: () => showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'selling'),
                                icon: Icons.sell_outlined,
                                isActive: isSelling,
                                activeColor: DollDexTheme.amber,
                                onPressed: () => showCollectionSheet(context, item),
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
                ],
              ),
            ),
          ],
        ),
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
    final finalColor = activeColor ?? const Color(0xFFEC008C);

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
                : (isDark ? const Color(0xFF160E22).withOpacity(0.5) : const Color(0xFFFAF2FF)),
            border: Border.all(
              color: isActive
                  ? finalColor
                  : (isNeonFlag
                      ? const Color(0xFFEC008C).withOpacity(isDark ? 0.6 : 0.8)
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
                          (activeColor ?? const Color(0xFF00FFCC)).withOpacity(isDark ? 0.5 : 0.85)
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
