import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../users/profile_setup_repository.dart';
import '../widgets/doll_widgets.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  CollectionStatus? _filter;
  CollectionCondition? _conditionFilter;
  int? _yearFilter;
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
          final yearEntries = _yearFilter == null
              ? condEntries
              : condEntries.where((entry) {
                  final item = findCatalogEntry(entry.itemId);
                  return item.year == _yearFilter;
                }).toList(growable: false);
          final filteredEntries = _query.isEmpty
              ? yearEntries
              : yearEntries.where((entry) {
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
                        color: Colors.black.withValues(alpha: 0.10),
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
                  selectedYear: _yearFilter,
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
                  onYearChanged: (val) {
                    setState(() {
                      _yearFilter = val;
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
    required this.selectedYear,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onConditionChanged,
    required this.onYearChanged,
    super.key,
  });

  final CollectionStatus? selectedStatus;
  final CollectionCondition? selectedCondition;
  final int? selectedYear;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CollectionStatus?> onStatusChanged;
  final ValueChanged<CollectionCondition?> onConditionChanged;
  final ValueChanged<int?> onYearChanged;

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
      splashColor: DollDexTheme.teal.withValues(alpha: 0.08),
      highlightColor: DollDexTheme.teal.withValues(alpha: 0.04),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? finalColor.withValues(alpha: 0.15)
              : (isDark ? DollDexTheme.darkPanel : DollDexTheme.panel),
          border: Border.all(
            color: isSelected
                ? finalColor
                : (isDark ? DollDexTheme.darkLine : DollDexTheme.line),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: finalColor.withValues(alpha: 0.20),
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
            color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
            width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                    selectedStatus == null && selectedCondition == null && selectedYear == null
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
        final currentUser = authService.currentUser;

        return StreamBuilder<ProfileSetupStatus>(
          stream: currentUser != null
              ? profileSetupRepository.watch(currentUser.uid)
              : const Stream.empty(),
          builder: (context, snap) {
            final isPro = snap.data?.isPro == true || snap.data?.role == 'admin';

            // Get all unique years in the system catalog
            final years = catalogEntriesNotifier.value
                .map((e) => e.year)
                .where((y) => y != null)
                .cast<int>()
                .toSet()
                .toList();
            years.sort((a, b) => b.compareTo(a));

            return Container(
              decoration: BoxDecoration(
                color: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          tr ? 'Yıla Göre Filtrele' : 'Filter by Year',
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_rounded, size: 14, color: Colors.orangeAccent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            context: context,
                            isSelected: selectedYear == null,
                            label: t(context, 'all'),
                            onTap: () {
                              if (!isPro) {
                                Navigator.of(context).pop();
                                showGothicConfirmDialog(
                                  context,
                                  title: tr ? 'Pro Yıl Filtresi' : 'Pro Year Filter',
                                  content: tr
                                      ? 'Yıla göre filtreleme yapmak DollDex Pro üyelerine özeldir. Pro\'ya yükseltmek ister misiniz?'
                                      : 'Filtering by year is exclusive to DollDex Pro members. Would you like to upgrade to Pro?',
                                  confirmText: tr ? 'Pro\'ya Geç' : 'Upgrade to Pro',
                                  cancelText: tr ? 'Vazgeç' : 'Cancel',
                                ).then((confirmed) {
                                  if (confirmed && context.mounted) {
                                    showProSubscriptionModal(context);
                                  }
                                });
                                return;
                              }
                              onYearChanged(null);
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(width: 8),
                          ...years.map((yr) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterChip(
                                context: context,
                                isSelected: selectedYear == yr,
                                label: yr.toString(),
                                onTap: () {
                                  if (!isPro) {
                                    Navigator.of(context).pop();
                                    showGothicConfirmDialog(
                                      context,
                                      title: tr ? 'Pro Yıl Filtresi' : 'Pro Year Filter',
                                      content: tr
                                          ? 'Yıla göre filtreleme yapmak DollDex Pro üyelerine özeldir. Pro\'ya yükseltmek ister misiniz?'
                                          : 'Filtering by year is exclusive to DollDex Pro members. Would you like to upgrade to Pro?',
                                      confirmText: tr ? 'Pro\'ya Geç' : 'Upgrade to Pro',
                                      cancelText: tr ? 'Vazgeç' : 'Cancel',
                                    ).then((confirmed) {
                                      if (confirmed && context.mounted) {
                                        showProSubscriptionModal(context);
                                      }
                                    });
                                    return;
                                  }
                                  onYearChanged(yr);
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
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
        final w = constraints.maxWidth;
        final columns = w >= 900 ? 7 : w >= 550 ? 5 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          cacheExtent: 1000,
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.58,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelected = selectedIds.contains(entry.id);
            return RepaintBoundary(
              child: CollectionGridCard(
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
              ),
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

    return PressableButton(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.96,
      borderRadius: 14,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Column(
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
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.80),
                                  Theme.of(context).colorScheme.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.30),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'x${entry.quantity}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E152C) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A1F3D) : const Color(0xFFEEE8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: DollDexTheme.teal,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
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
    cacheExtent: 1000,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.of(context).size.width >= 900
          ? 7
          : MediaQuery.of(context).size.width >= 550
              ? 5
              : 4,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
      childAspectRatio: 0.58,
    ),
    itemCount: categoryEntries.length,
    itemBuilder: (context, index) {
      final entry = categoryEntries[index];
      final item = findCatalogEntry(entry.itemId);

      void handleTap() {
        if (from == 'public_profile' && userId != null) {
          context.go('/c/${entry.id}?from=public_profile&userId=$userId');
        } else {
          context.go('/c/${entry.id}?from=$from');
        }
      }

      return RepaintBoundary(
        child: PressableButton(
          onTap: handleTap,
          scaleFactor: 0.96,
          borderRadius: 12,
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
        ),
      );
    },
  );
}

