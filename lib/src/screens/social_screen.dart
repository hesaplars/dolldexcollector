import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../core/web_image_helper.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../social/social_models.dart';
import '../users/user_models.dart';
import '../widgets/doll_widgets.dart';
import '../ads/ad_banner_widget.dart';
import '../catalog/catalog_models.dart';
import 'catalog_detail_screen.dart';
import '../comments/comment_models.dart';
import '../users/profile_setup_repository.dart';
import '../collection/collection_repository.dart';
import '../auth/sign_in_panel.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({this.chatUserId, super.key});

  final String? chatUserId;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      await performGoogleSignIn(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

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
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: GuestLoginBanner(),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PendingRequestsCard(userId: user.uid),
            const SizedBox(height: 8),
            Expanded(
              child: _GlobalChatCard(
                userId: user.uid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareItemSelectionModal extends StatefulWidget {
  const ShareItemSelectionModal({
    required this.userId,
    this.onShareCatalog,
    this.onShareCollection,
    super.key,
  });
  final String userId;
  final Future<void> Function(String catalogId)? onShareCatalog;
  final Future<void> Function(String catalogId, String collectionId, String status)? onShareCollection;

  @override
  State<ShareItemSelectionModal> createState() =>
      ShareItemSelectionModalState();
}

class ShareItemSelectionModalState extends State<ShareItemSelectionModal> {
  String _catalogSearchQuery = '';
  CatalogItemType? _catalogSelectedType;
  int? _catalogSelectedYear;

  String _collectionSearchQuery = '';
  CollectionStatus? _selectedCollectionStatus;
  CollectionCondition? _collectionSelectedCondition;
  int? _collectionSelectedYear;

  late Future<List<CollectionEntry>> _collectionFuture;

  @override
  void initState() {
    super.initState();
    _collectionFuture = collectionRepository.listForUser(widget.userId);
  }

  String getStatusLabel(BuildContext context, String status) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    switch (status) {
      case 'owned':
        return tr ? 'Sahibim' : 'Owned';
      case 'wanted':
        return tr ? 'Arıyorum' : 'Looking For';
      case 'trade':
        return tr ? 'Takaslık' : 'Trade';
      case 'selling':
        return tr ? 'Satılık' : 'Selling';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              tabs: [
                Tab(text: tr ? 'Katalog' : 'Catalog'),
                Tab(text: tr ? 'Koleksiyon' : 'Collection'),
              ],
            ),
            const AdBannerWidget(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCatalogTab(tr, isDark),
                  _buildCollectionTab(tr, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCatalogFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final currentUser = authService.currentUser;

        return StreamBuilder<ProfileSetupStatus>(
          stream: currentUser != null
              ? profileSetupRepository.watch(currentUser.uid)
              : const Stream.empty(),
          builder: (context, snap) {
            final isPro =
                snap.data?.isPro == true || snap.data?.role == 'admin';

            // Get unique years from the catalog
            final years = catalogEntriesNotifier.value
                .map((e) => e.year)
                .where((y) => y != null)
                .cast<int>()
                .toSet()
                .toList();
            years.sort((a, b) => b.compareTo(a));

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr ? 'Katalog Filtrele' : 'Filter Catalog',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr ? 'Öğe Türü' : 'Item Type',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChipHelper(
                          context: context,
                          isSelected: _catalogSelectedType == null,
                          label: tr ? 'Tümü' : 'All',
                          onTap: () {
                            setState(() {
                              _catalogSelectedType = null;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        for (final type in CatalogItemType.values)
                          _buildFilterChipHelper(
                            context: context,
                            isSelected: _catalogSelectedType == type,
                            label: catalogTypeLabel(context, type),
                            onTap: () {
                              final isRestricted = type == CatalogItemType.set ||
                                  type == CatalogItemType.pet ||
                                  type == CatalogItemType.accessory;
                              if (isRestricted && !isPro) {
                                Navigator.of(context).pop();
                                showProSubscriptionModal(context);
                              } else {
                                setState(() {
                                  _catalogSelectedType = type;
                                });
                                Navigator.of(context).pop();
                              }
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
                          _buildFilterChipHelper(
                            context: context,
                            isSelected: _catalogSelectedYear == null,
                            label: tr ? 'Tümü' : 'All',
                            onTap: () {
                              if (!isPro) {
                                Navigator.of(context).pop();
                                showProSubscriptionModal(context);
                                return;
                              }
                              setState(() {
                                _catalogSelectedYear = null;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(width: 8),
                          ...years.map((yr) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterChipHelper(
                                context: context,
                                isSelected: _catalogSelectedYear == yr,
                                label: yr.toString(),
                                onTap: () {
                                  if (!isPro) {
                                    Navigator.of(context).pop();
                                    showProSubscriptionModal(context);
                                    return;
                                  }
                                  setState(() {
                                    _catalogSelectedYear = yr;
                                  });
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

  void _showCollectionFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final currentUser = authService.currentUser;

        return StreamBuilder<ProfileSetupStatus>(
          stream: currentUser != null
              ? profileSetupRepository.watch(currentUser.uid)
              : const Stream.empty(),
          builder: (context, snap) {
            final isPro =
                snap.data?.isPro == true || snap.data?.role == 'admin';

            // Get unique years from the catalog
            final years = catalogEntriesNotifier.value
                .map((e) => e.year)
                .where((y) => y != null)
                .cast<int>()
                .toSet()
                .toList();
            years.sort((a, b) => b.compareTo(a));

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr ? 'Koleksiyon Filtrele' : 'Filter Collection',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr ? 'Koleksiyon Durumu' : 'Collection Status',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChipHelper(
                          context: context,
                          isSelected: _selectedCollectionStatus == null,
                          label: tr ? 'Tümü' : 'All',
                          onTap: () {
                            setState(() {
                              _selectedCollectionStatus = null;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        for (final status in CollectionStatus.values)
                          _buildFilterChipHelper(
                            context: context,
                            isSelected: _selectedCollectionStatus == status,
                            label: collectionStatusLabel(context, status),
                            onTap: () {
                              setState(() {
                                _selectedCollectionStatus = status;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr ? 'Parça Durumu' : 'Item Condition',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChipHelper(
                          context: context,
                          isSelected: _collectionSelectedCondition == null,
                          label: tr ? 'Tümü' : 'All',
                          onTap: () {
                            setState(() {
                              _collectionSelectedCondition = null;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        for (final condition in CollectionCondition.values)
                          _buildFilterChipHelper(
                            context: context,
                            isSelected: _collectionSelectedCondition == condition,
                            label: conditionLabel(context, condition),
                            onTap: () {
                              setState(() {
                                _collectionSelectedCondition = condition;
                              });
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
                          _buildFilterChipHelper(
                            context: context,
                            isSelected: _collectionSelectedYear == null,
                            label: tr ? 'Tümü' : 'All',
                            onTap: () {
                              if (!isPro) {
                                Navigator.of(context).pop();
                                showProSubscriptionModal(context);
                                return;
                              }
                              setState(() {
                                _collectionSelectedYear = null;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(width: 8),
                          ...years.map((yr) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterChipHelper(
                                context: context,
                                isSelected: _collectionSelectedYear == yr,
                                label: yr.toString(),
                                onTap: () {
                                  if (!isPro) {
                                    Navigator.of(context).pop();
                                    showProSubscriptionModal(context);
                                    return;
                                  }
                                  setState(() {
                                    _collectionSelectedYear = yr;
                                  });
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

  Widget _buildFilterChipHelper({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final finalColor =
        isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? finalColor.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected ? finalColor : Theme.of(context).dividerColor,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: finalColor.withValues(alpha: 0.25),
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
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogTab(bool tr, bool isDark) {
    final filteredCatalog = filterCatalogEntries(
      catalogEntriesNotifier.value,
      _catalogSearchQuery,
      _catalogSelectedType,
      year: _catalogSelectedYear,
    );

    final hasActiveFilter = _catalogSelectedType != null || _catalogSelectedYear != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _catalogSearchQuery = val),
                  style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    hintText: tr ? 'Bebek ara...' : 'Search dolls...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showCatalogFilterSheet(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasActiveFilter
                            ? (tr ? 'Aktif' : 'Active')
                            : (tr ? 'Hepsi' : 'All'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filteredCatalog.isEmpty
              ? Center(
                  child: Text(
                    tr ? 'Bebek bulunamadı.' : 'No dolls found.',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  cacheExtent: 800,
                  itemCount: filteredCatalog.length,
                  itemBuilder: (context, index) {
                    final entry = filteredCatalog[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: entry.primaryImageUrl.isNotEmpty
                              ? (kIsWeb
                                  ? getWebImage(
                                      imageUrl: entry.primaryImageUrl,
                                      label: entry.name,
                                      fit: entry.primaryImageUrl.toLowerCase().contains('.png')
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                    )
                                  : Image.network(
                                      entry.primaryImageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: entry.primaryImageUrl.toLowerCase().contains('.png')
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                    ))
                              : const Icon(Icons.image_not_supported_rounded,
                                  size: 24, color: Colors.grey),
                        ),
                        title: Text(
                          entry.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          entry.series ?? '',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        trailing: Icon(Icons.send_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16),
                        onTap: () async {
                          if (widget.onShareCatalog != null) {
                            await widget.onShareCatalog!(entry.id);
                          } else {
                            await socialRepository.sendGlobalMessage(
                              senderId: widget.userId,
                              text: '',
                              sharedCatalogId: entry.id,
                              sharedSource: 'catalog',
                            );
                          }
                          if (mounted) Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCollectionTab(bool tr, bool isDark) {
    return FutureBuilder<List<CollectionEntry>>(
      future: _collectionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
          );
        }

        final collectionEntries = snapshot.data ?? [];

        final List<MapEntry<CollectionEntry, CatalogEntry>> resolvedItems = [];
        for (final entry in collectionEntries) {
          final catalogItem = catalogEntriesNotifier.value.firstWhere(
            (e) => e.id == entry.itemId,
            orElse: () => const CatalogEntry(
              id: '',
              name: '',
              type: CatalogItemType.doll,
              subtitle: '',
              imageUrls: [],
            ),
          );
          if (catalogItem.id.isNotEmpty) {
            resolvedItems.add(MapEntry(entry, catalogItem));
          }
        }

        final filteredCollection = resolvedItems.where((pair) {
          final entry = pair.key;
          final catalogItem = pair.value;

          final matchesSearch = catalogItem.name
                  .toLowerCase()
                  .contains(_collectionSearchQuery.toLowerCase()) ||
              (catalogItem.series
                      ?.toLowerCase()
                      .contains(_collectionSearchQuery.toLowerCase()) ??
                  false);
          final matchesStatus = _selectedCollectionStatus == null ||
              entry.status == _selectedCollectionStatus;
          final matchesCondition = _collectionSelectedCondition == null ||
              entry.condition == _collectionSelectedCondition;
          final matchesYear = _collectionSelectedYear == null ||
              catalogItem.year == _collectionSelectedYear;

          return matchesSearch && matchesStatus && matchesCondition && matchesYear;
        }).toList();

        final hasActiveCollectionFilter = _selectedCollectionStatus != null ||
            _collectionSelectedCondition != null ||
            _collectionSelectedYear != null;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) =>
                          setState(() => _collectionSearchQuery = val),
                      style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                      decoration: InputDecoration(
                        hintText: tr
                            ? 'Koleksiyonunda ara...'
                            : 'Search your collection...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showCollectionFilterSheet(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1.0,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasActiveCollectionFilter
                                ? (tr ? 'Aktif' : 'Active')
                                : (tr ? 'Hepsi' : 'All'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filteredCollection.isEmpty
                  ? Center(
                      child: Text(
                        tr
                            ? 'Koleksiyon öğesi bulunamadı.'
                            : 'No collection items found.',
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      cacheExtent: 600,
                      itemCount: filteredCollection.length,
                      itemBuilder: (context, pairIndex) {
                        final pair = filteredCollection[pairIndex];
                        final colEntry = pair.key;
                        final catEntry = pair.value;
                        final statusLabel =
                            getStatusLabel(context, colEntry.status.name);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: catEntry.primaryImageUrl.isNotEmpty
                                  ? (kIsWeb
                                      ? getWebImage(
                                          imageUrl: catEntry.primaryImageUrl,
                                          label: catEntry.name,
                                          fit: catEntry.primaryImageUrl.toLowerCase().contains('.png')
                                              ? BoxFit.contain
                                              : BoxFit.cover,
                                        )
                                      : Image.network(
                                          catEntry.primaryImageUrl,
                                          width: 40,
                                          height: 40,
                                          fit: catEntry.primaryImageUrl.toLowerCase().contains('.png')
                                              ? BoxFit.contain
                                              : BoxFit.cover,
                                        ))
                                  : const Icon(
                                      Icons.image_not_supported_rounded,
                                      size: 24,
                                      color: Colors.grey),
                            ),
                            title: Text(
                              catEntry.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  catEntry.series ?? '',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.send_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 16),
                            onTap: () async {
                              if (widget.onShareCollection != null) {
                                await widget.onShareCollection!(
                                  catEntry.id,
                                  colEntry.id,
                                  colEntry.status.name,
                                );
                              } else {
                                await socialRepository.sendGlobalMessage(
                                  senderId: widget.userId,
                                  text: '',
                                  sharedCatalogId: catEntry.id,
                                  sharedCollectionId: colEntry.id,
                                  sharedCollectionStatus: colEntry.status.name,
                                  sharedSource: 'collection',
                                );
                              }
                              if (mounted) Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
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
  final _globalMessageFocusNode = FocusNode();

  String getStatusLabel(BuildContext context, String status) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    switch (status) {
      case 'owned':
        return tr ? 'Sahibim' : 'Owned';
      case 'wanted':
        return tr ? 'Arıyorum' : 'Looking For';
      case 'trade':
        return tr ? 'Takaslık' : 'Trade';
      case 'selling':
        return tr ? 'Satılık' : 'Selling';
      default:
        return status;
    }
  }

  Widget _buildSharedItemCard(
      BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final entry = catalogEntriesNotifier.value.firstWhere(
      (e) => e.id == msg.sharedCatalogId,
      orElse: () => const CatalogEntry(
        id: '',
        name: '',
        type: CatalogItemType.doll,
        subtitle: '',
        imageUrls: [],
      ),
    );

    if (entry.id.isEmpty) {
      return const SizedBox.shrink();
    }

    final statusLabel = getStatusLabel(context, msg.sharedCollectionStatus);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/i/${entry.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: entry.primaryImageUrl.isNotEmpty
                          ? (kIsWeb
                              ? getWebImage(
                                  imageUrl: entry.primaryImageUrl,
                                  label: entry.name,
                                  fit: entry.primaryImageUrl.toLowerCase().contains('.png')
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                )
                              : Image.network(
                                  entry.primaryImageUrl,
                                  fit: entry.primaryImageUrl.toLowerCase().contains('.png')
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_rounded,
                                          size: 20, color: Colors.grey),
                                ))
                          : const Icon(Icons.image_not_supported_rounded,
                              size: 20, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (entry.series != null &&
                            entry.series!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            entry.series!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                        if (statusLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _globalMessageController.dispose();
    _globalMessageFocusNode.dispose();
    super.dispose();
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
              ],
            ),
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
                    key: const PageStorageKey('global_chat_scroll'),
                    reverse: true,
                    cacheExtent: 500,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.userId;
                      return RepaintBoundary(
                        child: _buildGlobalMsgBubble(context, message, isMe),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  tooltip: tr ? 'Paylaş' : 'Share',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
    useRootNavigator: true,
                      showDragHandle: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      builder: (context) {
                        return ShareItemSelectionModal(userId: widget.userId);
                      },
                    );
                  },
                ),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
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

  Widget _buildGlobalMsgBubble(
      BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () {
                if (msg.senderUsername.isNotEmpty) {
                  final uName = msg.senderUsername.replaceAll('@', '');
                  context.push('/u/$uName');
                } else {
                  context.push('/users/${msg.senderId}');
                }
              },
              child: buildAvatarHelper(
                  context, msg.senderAvatarId, msg.senderFrameColor,
                  size: 32),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe) ...[
                      GestureDetector(
                        onTap: () {
                          if (msg.senderUsername.isNotEmpty) {
                            final uName =
                                msg.senderUsername.replaceAll('@', '');
                            context.push('/u/$uName');
                          } else {
                            context.push('/users/${msg.senderId}');
                          }
                        },
                        child: StreamBuilder<ProfileSetupStatus>(
                          stream: profileSetupRepository.watch(msg.senderId),
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
                                Text(
                                  msg.senderUsername.isEmpty
                                      ? msg.senderId
                                      : '@${msg.senderUsername}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    if (msg.text.isNotEmpty) ...[
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: isMe
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (msg.sharedSource.isNotEmpty) ...[
                      _buildSharedItemCard(context, msg, isMe),
                    ],
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
                            color: isMe
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withValues(alpha: 0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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
                      buildNeonIcon(context, Icons.people_outline_rounded,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr
                            ? 'Gelen Arkadaşlık İstekleri'
                            : 'Incoming Friend Requests',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
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
                    separatorBuilder: (context, index) =>
                        const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Row(
                        children: [
                          buildAvatarHelper(context, req.sender.avatarId,
                              req.sender.avatarFrameColor,
                              size: 36),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                            onPressed: () =>
                                _respond(context, req.sender.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
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
                            onPressed: () =>
                                _respond(context, req.sender.id, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                  width: 1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
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

  Future<void> _respond(
      BuildContext context, String fromUserId, bool accept) async {
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
