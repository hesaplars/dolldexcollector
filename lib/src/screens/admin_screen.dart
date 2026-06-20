import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../core/image_url_validator.dart';
import '../moderation/report_models.dart';
import '../widgets/doll_widgets.dart';
import '../admin/catalog_entry_form.dart';
import '../users/profile_setup_repository.dart';
import 'announcement_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _previewUrl = '';
  CatalogEntry? _editingEntry;

  @override
  Widget build(BuildContext context) {
    final userId = authService.currentUser?.uid;
    if (userId == null) {
      return PageShell(
        title: 'Admin',
        subtitle: t(context, 'adminSubtitle'),
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: t(context, 'adminOnly'),
          body: t(context, 'adminOnlyBody'),
        ),
      );
    }

    return PageShell(
      title: 'Admin',
      subtitle: t(context, 'adminSubtitle'),
      child: StreamBuilder<ProfileSetupStatus>(
        stream: profileSetupRepository.watch(userId),
        builder: (context, snapshot) {
          if (snapshot.data?.role != 'admin') {
            return EmptyState(
              icon: Icons.lock_outline_rounded,
              title: t(context, 'adminOnly'),
              body: t(context, 'adminOnlyBody'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 820;
              final formCard = Card(
                child: ExpansionTile(
                  key: ValueKey('admin-form-${_editingEntry?.id ?? "new"}'),
                  initiallyExpanded: _editingEntry != null,
                  title: Text(
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Katalog Giriş Formu'
                        : 'Catalog Entry Form',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  subtitle: Text(
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Yeni bebek, karakter, set, pet veya aksesuar ekleyin'
                        : 'Add a new doll, character, set, pet, or accessory',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: firebaseReadyNotifier,
                      builder: (context, ready, _) {
                        return _AdminStatusBanner(isFirebaseReady: ready);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_editingEntry != null) ...[
                      _EditingBanner(
                        entry: _editingEntry!,
                        onCancel: () {
                          setState(() {
                            _editingEntry = null;
                            _previewUrl = '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    CatalogEntryForm(
                      editingEntry: _editingEntry,
                      onPreviewChanged: (value) {
                        final urls = value.split(',').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
                        setState(() {
                          _previewUrl = (urls.isNotEmpty && ImageUrlValidator.isAllowed(urls.first))
                              ? urls.first
                              : '';
                        });
                      },
                      onSubmit: (draft) async {
                        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                        final confirmed = await showGothicConfirmDialog(
                          context,
                          title: tr ? 'Değişiklikleri Kaydet' : 'Save Changes',
                          content: tr
                              ? 'Katalog taslağını kaydetmek istediğinize emin misiniz?'
                              : 'Are you sure you want to save the catalog draft?',
                        );
                        if (!confirmed) return;

                        await saveCatalogDraft(context, draft);
                        setState(() {
                          _editingEntry = null;
                        });
                      },
                    ),
                  ],
                ),
              );
              final moderationQueue = const ModerationQueueScreen();
              final catalogButton = Card(
                child: ListTile(
                  leading: const Icon(Icons.collections_bookmark_rounded, color: DollDexTheme.teal),
                  title: Text(
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Kataloğu Yönet / Görüntüle'
                        : 'Manage / View Catalog',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Tüm kayıtlı katalog öğelerini ara, düzenle veya silebilirsiniz'
                        : 'Search, edit, or delete all registered catalog items',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    _showAdminCatalogModal(context, (entry) {
                      setState(() {
                        _editingEntry = entry;
                        _previewUrl = entry.primaryImageUrl;
                      });
                    });
                  },
                ),
              );

              final previewCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, 'imagePreview'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: DollImage(
                            imageUrl: _previewUrl,
                            label: t(context, 'pasteImageUrl'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t(context, 'savedEntriesImage'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );

              final announcementCard = const AnnouncementForm(key: ValueKey('admin-announcement-form'));

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          formCard,
                          const SizedBox(height: 16),
                          announcementCard,
                          const SizedBox(height: 16),
                          catalogButton,
                          const SizedBox(height: 16),
                          moderationQueue,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: previewCard),
                  ],
                );
              }

              return Column(
                children: [
                  formCard,
                  const SizedBox(height: 16),
                  announcementCard,
                  const SizedBox(height: 16),
                  previewCard,
                  const SizedBox(height: 16),
                  catalogButton,
                  const SizedBox(height: 16),
                  moderationQueue,
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class AdminCatalogManager extends StatelessWidget {
  const AdminCatalogManager({
    required this.onEdit,
    super.key,
  });

  final ValueChanged<CatalogEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'adminCatalog'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Sistemdeki tüm kayıtlı katalog öğelerini listeler. Kalem simgesiyle düzenleyebilir, çöp kutusu simgesiyle silebilirsiniz.'
                  : 'Lists all registered catalog items. Use the pencil icon to edit, or the trash icon to delete.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            ValueListenableBuilder<List<CatalogEntry>>(
              valueListenable: catalogEntriesNotifier,
              builder: (context, entries, _) {
                return Column(
                  children: [
                    for (final entry in entries)
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
                            leading: Icon(_catalogTypeIcon(entry.type)),
                            title: Text(
                              entryName(context, entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              entrySubtitle(context, entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => context.push('/catalog/${entry.id}'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: t(context, 'editEntry'),
                                  onPressed: () => onEdit(entry),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: t(context, 'deleteEntry'),
                                  onPressed: isTemplateEntry(entry)
                                      ? null
                                      : () async {
                                          final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                          final confirmed = await showGothicConfirmDialog(
                                            context,
                                            title: tr ? 'Öğeyi Sil' : 'Delete Item',
                                            content: tr
                                                ? '${entryName(context, entry)} öğesini katalogdan silmek istediğinize emin misiniz?'
                                                : 'Are you sure you want to delete ${entryName(context, entry)} from catalog?',
                                          );
                                          if (confirmed) {
                                            deleteCatalogEntry(entry.id);
                                          }
                                        },
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
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
    );
  }

  IconData _catalogTypeIcon(CatalogItemType type) {
    return switch (type) {
      CatalogItemType.character => Icons.person_outline_rounded,
      CatalogItemType.doll => Icons.checkroom_outlined,
      CatalogItemType.set => Icons.category_outlined,
      CatalogItemType.pet => Icons.pets_outlined,
      CatalogItemType.accessory => Icons.diamond_outlined,
    };
  }
}

void _showAdminCatalogModal(BuildContext context, ValueChanged<CatalogEntry> onEdit) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _AdminCatalogModalBody(
            scrollController: scrollController,
            onEdit: onEdit,
          );
        },
      );
    },
  );
}

class _AdminCatalogModalBody extends StatefulWidget {
  const _AdminCatalogModalBody({
    required this.scrollController,
    required this.onEdit,
  });

  final ScrollController scrollController;
  final ValueChanged<CatalogEntry> onEdit;

  @override
  State<_AdminCatalogModalBody> createState() => _AdminCatalogModalBodyState();
}

class _AdminCatalogModalBodyState extends State<_AdminCatalogModalBody> {
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<CatalogEntry> entries) {
    setState(() {
      if (_selectedIds.length == entries.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(entries.map((e) => e.id));
        _isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedEntries() async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final confirmed = await showGothicConfirmDialog(
      context,
      title: tr ? 'Katalogdan Sil' : 'Delete from Catalog',
      content: tr
          ? '${_selectedIds.length} adet katalog öğesini silmek istediğinize emin misiniz?'
          : 'Are you sure you want to delete ${_selectedIds.length} catalog items?',
      confirmText: tr ? 'Toplu Sil' : 'Bulk Delete',
    );

    if (confirmed == true) {
      for (final id in _selectedIds) {
        if (!_isTemplateEntryById(id)) {
          deleteCatalogEntry(id);
        }
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr ? 'Seçilen katalog öğeleri silindi.' : 'Selected items deleted.')),
      );
    }
  }

  bool _isTemplateEntryById(String id) {
    return id == 'template-character' || id == 'template-doll' || id == 'template-pet' || id == 'template-accessory';
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return ValueListenableBuilder<List<CatalogEntry>>(
      valueListenable: catalogEntriesNotifier,
      builder: (context, entries, _) {
        final filteredEntries = entries.where((entry) {
          final query = _searchQuery.toLowerCase();
          final name = entryName(context, entry).toLowerCase();
          final id = entry.id.toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: InputDecoration(
                        hintText: tr ? 'Katalogda ara...' : 'Search catalog...',
                        hintStyle: const TextStyle(fontFamily: 'Outfit'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF160E22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEC008C), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tr ? '${_selectedIds.length} Seçildi' : '${_selectedIds.length} Selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _selectAll(filteredEntries),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(
                          _selectedIds.length == filteredEntries.length 
                              ? (tr ? 'Seçimi Kaldır' : 'Deselect All')
                              : (tr ? 'Hepsini Seç' : 'Select All'),
                          style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _deleteSelectedEntries,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        tooltip: tr ? 'Toplu Sil' : 'Bulk Delete',
                      ),
                      IconButton(
                        onPressed: _cancelSelection,
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        tooltip: tr ? 'Vazgeç' : 'Cancel',
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(child: Text(tr ? 'Öğe bulunamadı' : 'No items found'))
                  : GridView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final isSelected = _selectedIds.contains(entry.id);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected 
                                  ? const Color(0xFFEC008C)
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? DollDexTheme.darkLine
                                      : DollDexTheme.line),
                              width: isSelected ? 3.0 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelect(entry.id);
                              } else {
                                final router = GoRouter.of(context);
                                Navigator.of(context).pop(); // Close modal
                                router.push('/catalog/${entry.id}'); // Route to item page
                              }
                            },
                            onLongPress: () {
                              _toggleSelect(entry.id);
                            },
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: Image.network(
                                          entry.primaryImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.withValues(alpha: 0.1),
                                              child: const Icon(Icons.broken_image_outlined, size: 36),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entryName(context, entry),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Text(
                                            catalogTypeLabel(context, entry.type),
                                            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelectionMode)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            iconSize: 18,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit_outlined),
                                            onPressed: () {
                                              widget.onEdit(entry);
                                              Navigator.of(context).pop(); // Close the modal
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            iconSize: 18,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline_rounded),
                                            onPressed: isTemplateEntry(entry)
                                                ? null
                                                : () async {
                                                    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                                    final confirmed = await showGothicConfirmDialog(
                                                      context,
                                                      title: tr ? 'Öğeyi Sil' : 'Delete Item',
                                                      content: tr
                                                          ? '${entryName(context, entry)} öğesini katalogdan silmek istediğinize emin misiniz?'
                                                          : 'Are you sure you want to delete ${entryName(context, entry)} from catalog?',
                                                    );
                                                    if (confirmed) {
                                                      deleteCatalogEntry(entry.id);
                                                    }
                                                  },
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                                if (isSelected)
                                  Container(
                                    color: const Color(0xFFEC008C).withValues(alpha: 0.25),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFFEC008C),
                                        size: 40,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

class _EditingBanner extends StatelessWidget {
  const _EditingBanner({
    required this.entry,
    required this.onCancel,
  });

  final CatalogEntry entry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DollDexTheme.teal.withValues(alpha: 0.1),
        border: Border.all(color: DollDexTheme.teal.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, color: DollDexTheme.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${t(context, 'editingEntry')}: ${entry.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton.outlined(
              tooltip: t(context, 'cancelEdit'),
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  int _activeTab = 0; // 0: Bekleyenler, 1: Tamamlananlar

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'moderationQueue'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              tr
                  ? 'Kullanıcılar tarafından bildirilen şüpheli yorumları ve katalog girdilerini buradan denetleyebilirsiniz.'
                  : 'You can moderate suspicious comments and catalog entries reported by users here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // Custom Tab Bar
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 0 ? const Color(0xFFEC008C) : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Text(
                        tr ? 'Bekleyenler' : 'Pending',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0
                              ? const Color(0xFFEC008C)
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 1 ? const Color(0xFFEC008C) : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Text(
                        tr ? 'Tamamlananlar' : 'Completed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 1
                              ? const Color(0xFFEC008C)
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<UserReport>>(
              valueListenable: reportsNotifier,
              builder: (context, reports, _) {
                final filtered = reports.where((report) {
                  final isPending = report.status == ReportStatus.open || report.status == ReportStatus.reviewing;
                  return _activeTab == 0 ? isPending : !isPending;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.report_gmailerrorred_outlined,
                    title: tr ? 'Rapor yok' : 'No reports',
                    body: tr ? 'Bu sekmede görüntülenecek rapor bulunamadı.' : 'No reports found to display in this tab.',
                  );
                }

                return Column(
                  children: [
                    for (final report in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ModerationReportCard(report: report),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ResolvedReportDetails {
  final String reporterName;
  final String reportedName;
  final String contentText;
  final String formattedTime;

  ResolvedReportDetails({
    required this.reporterName,
    required this.reportedName,
    required this.contentText,
    required this.formattedTime,
  });
}

Future<ResolvedReportDetails> _resolveReportDetails(BuildContext context, UserReport report) async {
  String reporterName = '...';
  String reportedName = '...';
  String contentText = '...';

  // 1. Raporlayan Kullanıcı adını çöz
  try {
    final repDoc = await FirebaseFirestore.instance.collection('users').doc(report.reporterId).get();
    if (repDoc.exists) {
      reporterName = repDoc.data()?['username'] as String? ?? 'Collector';
    } else {
      reporterName = 'ID: ${report.reporterId}';
    }
  } catch (_) {
    reporterName = 'ID: ${report.reporterId}';
  }

  // 2. Raporlanan Kullanıcı adını ve İçeriği çöz
  try {
    switch (report.targetType) {
      case ReportTargetType.user:
      case ReportTargetType.profile:
        final doc = await FirebaseFirestore.instance.collection('users').doc(report.targetId).get();
        if (doc.exists) {
          final username = doc.data()?['username'] as String? ?? 'Collector';
          reportedName = username;
          contentText = AppLanguageScope.languageOf(context) == AppLanguage.tr 
              ? 'Profil Sayfası (@$username)' 
              : 'Profile Page (@$username)';
        } else {
          reportedName = 'ID: ${report.targetId}';
          contentText = 'ID: ${report.targetId}';
        }
        break;
      case ReportTargetType.comment:
        final doc = await FirebaseFirestore.instance.collection('comments').doc(report.targetId).get();
        if (doc.exists) {
          final text = doc.data()?['text'] as String? ?? '';
          final authorId = doc.data()?['userId'] as String? ?? '';
          contentText = AppLanguageScope.languageOf(context) == AppLanguage.tr
              ? 'Yorum: "$text"'
              : 'Comment: "$text"';
          
          if (authorId.isNotEmpty) {
            final authDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
            if (authDoc.exists) {
              reportedName = authDoc.data()?['username'] as String? ?? 'Collector';
            } else {
              reportedName = 'ID: $authorId';
            }
          }
        } else {
          contentText = 'ID: ${report.targetId}';
        }
        break;
      case ReportTargetType.catalogEntry:
        final doc = await FirebaseFirestore.instance.collection('items').doc(report.targetId).get();
        if (doc.exists) {
          final name = doc.data()?['name'] as String? ?? '';
          contentText = AppLanguageScope.languageOf(context) == AppLanguage.tr
              ? 'Katalog: "$name"'
              : 'Catalog: "$name"';
        } else {
          contentText = 'ID: ${report.targetId}';
        }
        reportedName = 'System / Catalog';
        break;
      default:
        contentText = 'ID: ${report.targetId}';
        reportedName = '...';
        break;
    }
  } catch (_) {}

  // 3. Zamanı biçimlendir
  String formattedTime = formatMessageTime(report.createdAt);

  return ResolvedReportDetails(
    reporterName: reporterName,
    reportedName: reportedName,
    contentText: contentText,
    formattedTime: formattedTime,
  );
}

class ModerationReportCard extends StatelessWidget {
  const ModerationReportCard({required this.report, super.key});

  final UserReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? DollDexTheme.darkLine
              : DollDexTheme.line,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isDark
            ? DollDexTheme.darkPanel
            : Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildNeonFlagIcon(context, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportReasonLabel(context, report.reason),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<ResolvedReportDetails>(
                        future: _resolveReportDetails(context, report),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final d = snapshot.data!;
                          return RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Cinzel',
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: tr ? 'Raporlayan: ' : 'Reporter: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FFCC)),
                                ),
                                TextSpan(text: '@${d.reporterName}\n'),
                                TextSpan(
                                  text: tr ? 'Raporlanan: ' : 'Reported: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEC008C)),
                                ),
                                TextSpan(
                                  text: d.reportedName.startsWith('@') || d.reportedName.startsWith('ID:') || d.reportedName == 'System / Catalog'
                                      ? '${d.reportedName}\n'
                                      : '@${d.reportedName}\n',
                                ),
                                TextSpan(
                                  text: tr ? 'İçerik: ' : 'Content: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${d.contentText}\n'),
                                TextSpan(
                                  text: tr ? 'Zaman: ' : 'Time: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: d.formattedTime),
                                if (report.details.trim().isNotEmpty) ...[
                                  const TextSpan(text: '\n'),
                                  TextSpan(
                                    text: tr ? 'Detay: ' : 'Details: ',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: report.details.trim(),
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(reportStatusLabel(context, report.status)),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: DollDexTheme.teal.withOpacity(0.3)),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      icon: buildNeonIcon(context, Icons.more_vert_rounded, size: 22),
                      tooltip: tr ? 'İşlemler' : 'Actions',
                      onSelected: (value) async {
                        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                        switch (value) {
                          case 'open':
                            openReportTarget(context, report);
                            break;
                          case 'reviewing':
                            final confirmed = await showGothicConfirmDialog(
                              context,
                              title: tr ? 'İncelemeye Al' : 'Mark as Reviewing',
                              content: tr
                                  ? 'Bu raporu incelemeye almak istiyor musunuz?'
                                  : 'Do you want to mark this report as under review?',
                            );
                            if (confirmed) {
                              updateReportStatus(report.id, ReportStatus.reviewing);
                            }
                            break;
                          case 'dismissed':
                            final confirmed = await showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Reddet' : 'Dismiss Report',
                              content: tr
                                  ? 'Bu raporu reddetmek/kapatmak istiyor musunuz?'
                                  : 'Do you want to dismiss and close this report?',
                            );
                            if (confirmed) {
                              updateReportStatus(report.id, ReportStatus.dismissed);
                            }
                            break;
                          case 'resolved':
                            final confirmed = await showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Çöz' : 'Resolve Report',
                              content: tr
                                  ? 'Bu raporu çözüldü olarak işaretlemek istiyor musunuz?'
                                  : 'Do you want to mark this report as resolved?',
                            );
                            if (confirmed) {
                              updateReportStatus(report.id, ReportStatus.resolved);
                            }
                            break;
                          case 'delete':
                            final confirmed = await showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Sil' : 'Delete Report',
                              content: tr
                                  ? 'Bu rapor kaydını silmek istiyor musunuz?'
                                  : 'Do you want to delete this report record?',
                            );
                            if (confirmed) {
                              deleteReport(report.id);
                            }
                            break;
                          case 'destroy':
                            await deleteReportedContent(context, report);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              buildNeonIcon(context, Icons.open_in_new_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'openTarget')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reviewing',
                          child: Row(
                            children: [
                              buildNeonIcon(context, Icons.visibility_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'markReviewing')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'dismissed',
                          child: Row(
                            children: [
                              buildNeonIcon(context, Icons.block_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'dismissReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Row(
                            children: [
                              buildNeonIcon(context, Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'resolveReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              buildNeonIcon(context, Icons.delete_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'delete')),
                            ],
                          ),
                        ),
                        if (report.targetType == ReportTargetType.comment ||
                            report.targetType == ReportTargetType.catalogEntry)
                          PopupMenuItem(
                            value: 'destroy',
                            child: Row(
                              children: [
                                buildNeonIcon(context, Icons.delete_forever_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  tr ? 'İçeriği İmha Et' : 'Destroy Content',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatusBanner extends StatelessWidget {
  const _AdminStatusBanner({required this.isFirebaseReady});

  final bool isFirebaseReady;

  @override
  Widget build(BuildContext context) {
    final color = isFirebaseReady ? DollDexTheme.teal : DollDexTheme.amber;
    final text = isFirebaseReady
        ? 'Firebase bağlı. Kayıtlar Firestore veritabanına yazılır.'
        : 'Firebase henüz bağlı değil. Kayıtlar bu oturumda geçici kalır.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isFirebaseReady
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
