import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  CollectionStatus? _filter;
  CollectionCondition? _conditionFilter;
  String _query = '';
  final Set<String> _selectedEntryIds = {};
  bool _isSelectionMode = false;

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
      } else {
        _selectedEntryIds.add(id);
      }
      if (_selectedEntryIds.isEmpty) {
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<CollectionEntry> entries) {
    setState(() {
      if (_selectedEntryIds.length == entries.length) {
        _selectedEntryIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedEntryIds.addAll(entries.map((e) => e.id));
        _isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedEntryIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedEntries() async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final confirmed = await showGothicConfirmDialog(
      context,
      title: tr ? 'Koleksiyondan Sil' : 'Delete from Collection',
      content: tr
          ? '${_selectedEntryIds.length} adet bebeği koleksiyonunuzdan silmek istediğinize emin misiniz?'
          : 'Are you sure you want to delete ${_selectedEntryIds.length} dolls from your collection?',
      confirmText: tr ? 'Toplu Sil' : 'Bulk Delete',
    );

    if (confirmed == true) {
      final userId = authService.currentUser?.uid ?? 'local-user';
      if (true) {
        for (final entryId in _selectedEntryIds) {
          final dummyEntry = CollectionEntry(
            id: entryId,
            userId: userId,
            itemId: '',
            status: CollectionStatus.owned,
            condition: CollectionCondition.complete,
            quantity: 1,
            notes: '',
            isPublic: false,
          );
          await collectionRepository.delete(dummyEntry);
        }
        collectionEntriesNotifier.value = collectionEntriesNotifier.value
            .where((entry) => !_selectedEntryIds.contains(entry.id))
            .toList();
        setState(() {
          _selectedEntryIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(tr ? 'Seçilenler silindi.' : 'Selected items deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return PageShell(
      listViewKey: const PageStorageKey('collection_scroll'),
      title: t(context, 'collection'),
      subtitle: t(context, 'collectionSubtitle'),
      child: ValueListenableBuilder<List<CollectionEntry>>(
        valueListenable: collectionEntriesNotifier,
        builder: (context, entries, _) {
          final visibleEntries = _filter == null
              ? entries
              : entries
                  .where((entry) => entry.status == _filter)
                  .toList(growable: false);
          final condEntries = _conditionFilter == null
              ? visibleEntries
              : visibleEntries
                  .where((entry) => entry.condition == _conditionFilter)
                  .toList(growable: false);
          final filteredEntries = _query.isEmpty
              ? condEntries
              : condEntries.where((entry) {
                  final item = findCatalogEntry(entry.itemId);
                  final name = entryName(context, item).toLowerCase();
                  return name.contains(_query.toLowerCase());
                }).toList(growable: false);

          return Column(
            children: [
              if (authService.currentUser == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: GuestLoginBanner(),
                ),
              StatRow(entries: entries),
              const SizedBox(height: 16),
              if (_isSelectionMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).cardTheme.color ?? DollDexTheme.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DollDexTheme.line, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        tr
                            ? '${_selectedEntryIds.length} Seçildi'
                            : '${_selectedEntryIds.length} Selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: DollDexTheme.ink,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _selectAll(filteredEntries),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: Text(
                          _selectedEntryIds.length == filteredEntries.length
                              ? (tr ? 'Seçimi Kaldır' : 'Deselect All')
                              : (tr ? 'Hepsini Seç' : 'Select All'),
                          style: const TextStyle(
                            color: DollDexTheme.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _deleteSelectedEntries,
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 20),
                        tooltip: tr ? 'Toplu Sil' : 'Bulk Delete',
                      ),
                      IconButton(
                        onPressed: _cancelSelection,
                        icon: const Icon(Icons.close_rounded,
                            color: DollDexTheme.cocoa, size: 20),
                        tooltip: tr ? 'Vazgeç' : 'Cancel',
                      ),
                    ],
                  ),
                )
              else
                CollectionSearchPanel(
                  selectedStatus: _filter,
                  selectedCondition: _conditionFilter,
                  onQueryChanged: (val) {
                    setState(() {
                      _query = val;
                    });
                  },
                  onStatusChanged: (val) {
                    setState(() {
                      _filter = val;
                    });
                  },
                  onConditionChanged: (val) {
                    setState(() {
                      _conditionFilter = val;
                    });
                  },
                ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: t(context, 'yourShelfReady'),
                  body: t(context, 'yourShelfBody'),
                )
              else if (filteredEntries.isEmpty)
                EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: t(context, 'noCollectionFilterResults'),
                  body: t(context, 'noCollectionFilterResultsBody'),
                )
              else
                CollectionEntryList(
                  entries: filteredEntries,
                  selectedIds: _selectedEntryIds,
                  isSelectionMode: _isSelectionMode,
                  onToggleSelect: _toggleSelect,
                ),
            ],
          );
        },
      ),
    );
  }
}

class CollectionSearchPanel extends StatelessWidget {
  const CollectionSearchPanel({
    required this.selectedStatus,
    required this.selectedCondition,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onConditionChanged,
    super.key,
  });

  final CollectionStatus? selectedStatus;
  final CollectionCondition? selectedCondition;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CollectionStatus?> onStatusChanged;
  final ValueChanged<CollectionCondition?> onConditionChanged;

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                ? (isDark ? Colors.white : DollDexTheme.teal)
                : (isDark ? Colors.white60 : DollDexTheme.cocoa),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
        borderRadius: BorderRadius.circular(22),
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
          buildNeonIcon(context, Icons.search_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : DollDexTheme.ink,
                  fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: tr ? 'Koleksiyonda ara...' : 'Search in shelf...',
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
            onTap: () => _showCollectionFilterSheet(context),
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
                  buildNeonIcon(context, Icons.tune_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    selectedStatus == null && selectedCondition == null
                        ? (tr ? 'Filtre' : 'Filter')
                        : (tr ? 'Aktif' : 'Active'),
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

  void _showCollectionFilterSheet(BuildContext context) {
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
                tr ? 'Koleksiyon Filtrele' : 'Filter Collection',
                style: TextStyle(
                  color: isDark ? Colors.white : DollDexTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr ? 'Koleksiyon Durumu' : 'Collection Status',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    context: context,
                    isSelected: selectedStatus == null,
                    label: t(context, 'all'),
                    onTap: () {
                      onStatusChanged(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final status in CollectionStatus.values)
                    _buildFilterChip(
                      context: context,
                      isSelected: selectedStatus == status,
                      label: collectionStatusLabel(context, status),
                      onTap: () {
                        onStatusChanged(status);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tr ? 'Parça Durumu' : 'Item Condition',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    context: context,
                    isSelected: selectedCondition == null,
                    label: t(context, 'allConditions'),
                    onTap: () {
                      onConditionChanged(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final condition in CollectionCondition.values)
                    _buildFilterChip(
                      context: context,
                      isSelected: selectedCondition == condition,
                      label: conditionLabel(context, condition),
                      onTap: () {
                        onConditionChanged(condition);
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

class StatRow extends StatelessWidget {
  const StatRow({required this.entries, super.key});

  final List<CollectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final owned =
        entries.where((entry) => entry.status == CollectionStatus.owned).length;
    final wanted = entries
        .where((entry) => entry.status == CollectionStatus.wanted)
        .length;
    final trade =
        entries.where((entry) => entry.status == CollectionStatus.trade).length;
    final selling = entries
        .where((entry) => entry.status == CollectionStatus.selling)
        .length;

    return Row(
      children: [
        Expanded(child: StatCard(label: t(context, 'owned'), value: '$owned')),
        const SizedBox(width: 8),
        Expanded(
            child: StatCard(label: t(context, 'wanted'), value: '$wanted')),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: t(context, 'trade'), value: '$trade')),
        const SizedBox(width: 8),
        Expanded(
            child: StatCard(label: t(context, 'selling'), value: '$selling')),
      ],
    );
  }
}

class CollectionEntryList extends StatelessWidget {
  const CollectionEntryList({
    required this.entries,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggleSelect,
    super.key,
  });

  final List<CollectionEntry> entries;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final ValueChanged<String> onToggleSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.58,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelected = selectedIds.contains(entry.id);
            return CollectionGridCard(
              entry: entry,
              isSelected: isSelected,
              isSelectionMode: isSelectionMode,
              onTap: () {
                if (isSelectionMode) {
                  onToggleSelect(entry.id);
                } else {
                  context.go('/c/${entry.id}?from=collection');
                }
              },
              onLongPress: () {
                onToggleSelect(entry.id);
              },
            );
          },
        );
      },
    );
  }
}

class CollectionGridCard extends StatelessWidget {
  const CollectionGridCard({
    required this.entry,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final CollectionEntry entry;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final item = findCatalogEntry(entry.itemId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPng = item.primaryImageUrl.toLowerCase().contains('.png');

    return Card(
      color: isPng ? Colors.transparent : null,
      elevation: isPng ? 0 : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isPng ? Colors.transparent : Theme.of(context).dividerColor),
          width: isSelected ? 3.0 : (isPng ? 0.0 : 1.5),
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DollImage(
                        imageUrl: item.primaryImageUrl,
                        label: entryName(context, item),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTap,
                            onLongPress: onLongPress,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25),
                          child: Center(
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 40,
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
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildStatusIcon(context, entry.status),
                                Text(
                                  collectionStatusLabel(context, entry.status),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'x${entry.quantity}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, CollectionStatus status) {
    final icon = switch (status) {
      CollectionStatus.owned => Icons.check_circle_outline_rounded,
      CollectionStatus.wanted => Icons.favorite_border_rounded,
      CollectionStatus.trade => Icons.swap_horiz_rounded,
      CollectionStatus.selling => Icons.sell_outlined,
    };
    return buildGothicNeonIconButton(
      context: context,
      icon: icon,
      size: 10,
      padding: const EdgeInsets.all(3),
      activeColor: Theme.of(context).colorScheme.secondary,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DollDexTheme.teal,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class CollectionCategoryTab extends StatefulWidget {
  const CollectionCategoryTab({
    required this.entries,
    this.from = 'collection',
    this.userId,
    super.key,
  });

  final List<CollectionEntry> entries;
  final String from;
  final String? userId;

  @override
  State<CollectionCategoryTab> createState() => _CollectionCategoryTabState();
}

class _CollectionCategoryTabState extends State<CollectionCategoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildCollectionCategoryTab(
      context,
      widget.entries,
      from: widget.from,
      userId: widget.userId,
    );
  }
}

Widget _buildCollectionCategoryTab(
  BuildContext context,
  List<CollectionEntry> categoryEntries, {
  required String from,
  String? userId,
}) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  if (categoryEntries.isEmpty) {
    return Center(
      child: Text(
        tr ? 'Bu kategoride öge yok' : 'No items in this category',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.grey),
      ),
    );
  }

  return GridView.builder(
    padding: const EdgeInsets.all(3),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
      childAspectRatio: 0.58,
    ),
    itemCount: categoryEntries.length,
    itemBuilder: (context, index) {
      final entry = categoryEntries[index];
      final item = findCatalogEntry(entry.itemId);
      final isPng = item.primaryImageUrl.toLowerCase().contains('.png');

      void handleTap() {
        if (from == 'public_profile' && userId != null) {
          context.go('/c/${entry.id}?from=public_profile&userId=$userId');
        } else {
          context.go('/c/${entry.id}?from=$from');
        }
      }

      return Card(
        color: isPng ? Colors.transparent : null,
        elevation: isPng ? 0 : 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: handleTap,
          child: Column(
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
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: handleTap,
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
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tr ? 'Adet' : 'Qty'}: ${entry.quantity}',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Outfit',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
