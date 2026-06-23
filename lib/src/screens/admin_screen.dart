import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../moderation/report_models.dart';
import '../widgets/doll_widgets.dart';
import '../admin/catalog_entry_form.dart';
import '../users/profile_setup_repository.dart';
import '../users/user_models.dart';
import '../social/social_repository.dart';
import 'announcement_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  CatalogEntry? _editingEntry;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  void _openCoinManagementDialog(AppUser user) async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final profile = await profileSetupRepository.getProfile(user.id);
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr
                  ? 'Kullanıcı profili bulunamadı.'
                  : 'User profile not found.')),
        );
      }
      return;
    }

    int currentCoins = profile.coins;
    final coinController = TextEditingController(text: '$currentCoins');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                tr
                    ? '@${profile.username} Jeton Yönetimi'
                    : 'Manage Coins for @${profile.username}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr
                        ? 'Mevcut Bakiye: $currentCoins jeton'
                        : 'Current Balance: $currentCoins coins',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 50, 100, 500].map((amount) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            currentCoins += amount;
                            coinController.text = '$currentCoins';
                          });
                        },
                        child: Text('+$amount'),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: coinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      labelText: tr ? 'Toplam Jeton Sayısı' : 'Total Coins',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      setDialogState(() {
                        currentCoins = parsed;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr ? 'İptal' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newCoins =
                        int.tryParse(coinController.text) ?? currentCoins;
                    await profileSetupRepository.updateCoins(
                        profile.userId, newCoins);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                tr ? 'Jeton güncellendi.' : 'Coins updated.')),
                      );
                    }
                  },
                  child: Text(tr ? 'Kaydet' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openModerationBottomSheet(AppUser user) async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final profile = await profileSetupRepository.getProfile(user.id);
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr
                  ? 'Kullanıcı profili bulunamadı.'
                  : 'User profile not found.')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final banText = profile.isBanned
                ? (tr ? 'Kalıcı Yasaklı' : 'Permanently Banned')
                : (profile.banUntil != null &&
                        profile.banUntil!.isAfter(DateTime.now())
                    ? (tr
                        ? 'Geçici Askıda (${profile.banUntil!.toLocal()})'
                        : 'Suspended until (${profile.banUntil!.toLocal()})')
                    : (tr ? 'Aktif' : 'Active'));

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr
                          ? '@${profile.username} Moderasyonu'
                          : 'Moderation for @${profile.username}',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tr ? "Durum:" : "Status:"} $banText\n${tr ? "Rol:" : "Role:"} ${profile.role.toUpperCase()} (Pro: ${profile.isPro})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            icon: const Icon(Icons.block_flipped),
                            label:
                                Text(tr ? 'Süresiz Engelle' : 'Permanent Ban'),
                            onPressed: () async {
                              final confirmed = await showGothicConfirmDialog(
                                context,
                                title: tr ? 'Süresiz Engelle' : 'Permanent Ban',
                                content: tr
                                    ? '@${profile.username} kullanıcısını süresiz olarak engellemek istiyor musunuz?'
                                    : 'Do you want to permanently ban @${profile.username}?',
                              );
                              if (!confirmed) return;
                              await profileSetupRepository.updateBanStatus(
                                  profile.userId,
                                  isBanned: true);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Kullanıcı süresiz engellendi.'
                                          : 'User permanently banned.')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              side:
                                  const BorderSide(color: Colors.orangeAccent),
                            ),
                            icon: const Icon(Icons.timer_outlined),
                            label:
                                Text(tr ? 'Süreli Engelle' : 'Temp Suspension'),
                            onPressed: () async {
                              final now = DateTime.now();
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: now.add(const Duration(days: 1)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                              );
                              if (pickedDate == null) return;
                              if (!context.mounted) return;
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 0, minute: 0),
                              );
                              if (pickedTime == null) return;

                              final banUntilDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );

                              final confirmed = await showGothicConfirmDialog(
                                context,
                                title: tr
                                    ? 'Süreli Askıya Al'
                                    : 'Suspend Temporarily',
                                content: tr
                                    ? '@${profile.username} kullanıcısını şu tarihe kadar askıya almak istiyor musunuz: $banUntilDateTime?'
                                    : 'Do you want to suspend @${profile.username} until $banUntilDateTime?',
                              );
                              if (!confirmed) return;

                              await profileSetupRepository.updateBanStatus(
                                profile.userId,
                                isBanned: false,
                                banUntil: banUntilDateTime,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Kullanıcı süreli askıya alındı.'
                                          : 'User suspended temporarily.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(tr ? 'Engeli Kaldır' : 'Unban User'),
                            onPressed: () async {
                              await profileSetupRepository.updateBanStatus(
                                  profile.userId,
                                  isBanned: false,
                                  banUntil: null);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Kullanıcı engeli kaldırıldı.'
                                          : 'User unbanned.')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.grey),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label:
                                Text(tr ? 'Profili Sıfırla' : 'Reset Profile'),
                            onPressed: () async {
                              final confirmed = await showGothicConfirmDialog(
                                context,
                                title: tr ? 'Profili Sıfırla' : 'Reset Profile',
                                content: tr
                                    ? '@${profile.username} kullanıcısının avatarını, kapak fotoğrafını ve vitrin öğelerini sıfırlamak istiyor musunuz?'
                                    : 'Do you want to reset avatar, cover, and featured entries for @${profile.username}?',
                              );
                              if (!confirmed) return;
                              await profileSetupRepository
                                  .resetProfileContent(profile.userId);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Profil sıfırlandı.'
                                          : 'Profile reset completed.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              side: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                            ),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: Text(profile.role == 'admin'
                                ? (tr ? 'Adminliği Al' : 'Remove Admin')
                                : (tr ? 'Admin Yap' : 'Make Admin')),
                            onPressed: () async {
                              final newRole =
                                  profile.role == 'admin' ? 'user' : 'admin';
                              await profileSetupRepository.updateRoleAndPro(
                                  profile.userId,
                                  role: newRole,
                                  isPro: profile.isPro);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Rol güncellendi.'
                                          : 'Role updated.')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purpleAccent,
                              side:
                                  const BorderSide(color: Colors.purpleAccent),
                            ),
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: Text(profile.isPro
                                ? (tr ? 'Pro İptal Et' : 'Cancel Pro')
                                : (tr ? 'Pro Yap' : 'Make Pro')),
                            onPressed: () async {
                              final newPro = !profile.isPro;
                              await profileSetupRepository.updateRoleAndPro(
                                  profile.userId,
                                  role: profile.role,
                                  isPro: newPro);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr
                                          ? 'Pro durumu güncellendi.'
                                          : 'Pro status updated.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: Text(tr
                          ? 'Üyeliği Tamamen Sil'
                          : 'Delete Account Completely'),
                      onPressed: () async {
                        final confirmed = await showGothicConfirmDialog(
                          context,
                          title: tr
                              ? 'Hesabı Tamamen Sil'
                              : 'Delete Account Completely',
                          content: tr
                              ? '@${profile.username} kullanıcısının tüm profil verilerini, kullanıcı adını, koleksiyonunu ve bildirimlerini KALICI OLARAK silmek istiyor musunuz? Bu işlem geri alınamaz!'
                              : 'Are you sure you want to PERMANENTLY delete @${profile.username}\'s profile, collection, notifications, and release the username? This cannot be undone!',
                        );
                        if (!confirmed) return;
                        await profileSetupRepository.adminDeleteUserAccount(
                            profile.userId, profile.username);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(tr
                                    ? 'Kullanıcı hesabı tamamen silindi.'
                                    : 'User account successfully deleted.')),
                          );
                        }
                      },
                    ),
                    const Divider(height: 24),
                    Text(
                      tr
                          ? 'Kişiye Özel Bildirim/Uyarı Gönder'
                          : 'Send Custom Notification/Warning',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _CustomWarningForm(
                      userId: profile.userId,
                      onSent: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(tr
                                  ? 'Uyarı bildirimi gönderildi.'
                                  : 'Warning notification sent.')),
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
  @override
  Widget build(BuildContext context) {
    final userId = authService.currentUser?.uid;

    try {
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['open_catalog_modal'] == 'true') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final newUri = uri.replace(
            queryParameters: Map<String, String>.from(uri.queryParameters)
              ..remove('open_catalog_modal'),
          );
          GoRouter.of(context).replace(newUri.toString());
          _showAdminCatalogModal(context, (entry) {
            setState(() {
              _editingEntry = entry;
            });
          });
        });
      }
    } catch (_) {}
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
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    CatalogEntryForm(
                      editingEntry: _editingEntry,
                      onSubmit: (draft) async {
                        final tr = AppLanguageScope.languageOf(context) ==
                            AppLanguage.tr;
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
                  leading: const Icon(Icons.collections_bookmark_rounded,
                      color: DollDexTheme.teal),
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
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    _showAdminCatalogModal(context, (entry) {
                      setState(() {
                        _editingEntry = entry;
                      });
                    });
                  },
                ),
              );

              final coinManagementCard = AdminUserSearchCard(
                title: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Jeton Yönetimi'
                    : 'Coin Management',
                subtitle: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Kullanıcı adı aratarak jeton ekleyin veya bakiye belirleyin'
                    : 'Search username to add coins or set balance',
                icon: Icons.monetization_on_outlined,
                iconColor: Colors.amber,
                onUserSelected: _openCoinManagementDialog,
              );

              final userManagementCard = AdminUserSearchCard(
                title: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Kullanıcı Yönetimi & Güvenlik'
                    : 'User Management & Security',
                subtitle: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Engelleme, askıya alma, üyelik silme, Pro rolü yetkilendirme ve özel uyarılar'
                    : 'Ban, suspend, delete accounts, Pro role toggling, and warning alerts',
                icon: Icons.admin_panel_settings_outlined,
                iconColor: Theme.of(context).colorScheme.primary,
                onUserSelected: _openModerationBottomSheet,
              );
              final announcementCard = const AnnouncementForm(
                  key: ValueKey('admin-announcement-form'));

              final popupAnnouncementCard = const AdminPopupAnnouncementCard(
                  key: ValueKey('admin-popup-announcement-card'));

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
                          catalogButton,
                          const SizedBox(height: 16),
                          moderationQueue,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          announcementCard,
                          const SizedBox(height: 16),
                          popupAnnouncementCard,
                          const SizedBox(height: 16),
                          coinManagementCard,
                          const SizedBox(height: 16),
                          userManagementCard,
                          const SizedBox(height: 16),
                          const AdminMonetizationCard(),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  formCard,
                  const SizedBox(height: 16),
                  catalogButton,
                  const SizedBox(height: 16),
                  moderationQueue,
                  const SizedBox(height: 16),
                  announcementCard,
                  const SizedBox(height: 16),
                  popupAnnouncementCard,
                  const SizedBox(height: 16),
                  coinManagementCard,
                  const SizedBox(height: 16),
                  userManagementCard,
                  const SizedBox(height: 16),
                  const AdminMonetizationCard(),
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
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
                            onTap: () => context.go('/i/${entry.id}'),
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
                                  onPressed: () async {
                                    final tr =
                                        AppLanguageScope.languageOf(context) ==
                                            AppLanguage.tr;
                                    final confirmed =
                                        await showGothicConfirmDialog(
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
                                  icon: const Icon(Icons.delete_outline_rounded),
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

void _showAdminCatalogModal(
    BuildContext context, ValueChanged<CatalogEntry> onEdit) {
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
  CatalogItemType? _selectedTypeFilter;

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
        deleteCatalogEntry(id);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr
                ? 'Seçilen katalog öğeleri silindi.'
                : 'Selected items deleted.')),
      );
    }
  }

  bool _isTemplateEntryById(String id) {
    return id == 'template-character' ||
        id == 'template-doll' ||
        id == 'template-pet' ||
        id == 'template-accessory';
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
                    isSelected: _selectedTypeFilter == null,
                    label: tr ? 'Hepsi' : 'All',
                    onTap: () {
                      setState(() {
                        _selectedTypeFilter = null;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final type in CatalogItemType.values)
                    _buildFilterChip(
                      context: context,
                      isSelected: _selectedTypeFilter == type,
                      label: catalogTypeLabel(context, type),
                      onTap: () {
                        setState(() {
                          _selectedTypeFilter = type;
                        });
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

  Widget _buildFilterChip({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final finalColor = isSelected ? primaryColor : Colors.transparent;

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
            fontSize: 12,
            fontFamily: 'Outfit',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white70 : DollDexTheme.cocoa),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<List<CatalogEntry>>(
      valueListenable: catalogEntriesNotifier,
      builder: (context, entries, _) {
        final filteredEntries = entries.where((entry) {
          final query = _searchQuery.toLowerCase();
          final name = entryName(context, entry).toLowerCase();
          final id = entry.id.toLowerCase();
          final matchesQuery = name.contains(query) || id.contains(query);
          if (_selectedTypeFilter != null) {
            return matchesQuery && entry.type == _selectedTypeFilter;
          }
          return matchesQuery;
        }).toList();

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : DollDexTheme.ink,
                          fontFamily: 'Outfit'),
                      decoration: InputDecoration(
                        hintText: tr ? 'Katalogda ara...' : 'Search catalog...',
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
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
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
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedTypeFilter == null
                                ? (tr ? 'Hepsi' : 'All')
                                : catalogTypeLabel(context, _selectedTypeFilter!),
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
            ),
            if (_isSelectionMode)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tr
                            ? '${_selectedIds.length} Seçildi'
                            : '${_selectedIds.length} Selected',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _selectAll(filteredEntries),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: Text(
                          _selectedIds.length == filteredEntries.length
                              ? (tr ? 'Seçimi Kaldır' : 'Deselect All')
                              : (tr ? 'Hepsini Seç' : 'Select All'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _deleteSelectedEntries,
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 18),
                        tooltip: tr ? 'Toplu Sil' : 'Bulk Delete',
                      ),
                      IconButton(
                        onPressed: _cancelSelection,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 18),
                        tooltip: tr ? 'Vazgeç' : 'Cancel',
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Text(tr ? 'Öğe bulunamadı' : 'No items found'))
                  : GridView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final isSelected = _selectedIds.contains(entry.id);
                        final isMobile = MediaQuery.of(context).size.width <= 600;
                        final titleSize = isMobile ? 9.5 : 12.0;
                        final typeSize = isMobile ? 8.0 : 10.0;
                        final iconSize = isMobile ? 14.0 : 18.0;
                        final paddingVal = isMobile ? 4.0 : 8.0;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? DollDexTheme.darkLine
                                      : DollDexTheme.line),
                              width: isSelected ? 2.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelect(entry.id);
                              } else {
                                context.push('/i/${entry.id}?from=admin_catalog_modal');
                              }
                            },
                            onLongPress: () {
                              _toggleSelect(entry.id);
                            },
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(8)),
                                        child: Image.network(
                                          entry.primaryImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey
                                                  .withValues(alpha: 0.1),
                                              child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: isMobile ? 24 : 36),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(paddingVal),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entryName(context, entry),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: titleSize),
                                          ),
                                          Text(
                                            catalogTypeLabel(
                                                context, entry.type),
                                            style: TextStyle(
                                                fontSize: typeSize,
                                                color: Theme.of(context)
                                                    .hintColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelectionMode)
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: paddingVal),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              iconSize: iconSize,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon:
                                                  const Icon(Icons.edit_outlined),
                                              onPressed: () {
                                                widget.onEdit(entry);
                                                Navigator.of(context)
                                                    .pop(); // Close the modal
                                              },
                                            ),
                                            SizedBox(width: isMobile ? 4 : 8),
                                            IconButton(
                                              iconSize: iconSize,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded),
                                              onPressed: () async {
                                                final tr = AppLanguageScope
                                                        .languageOf(
                                                            context) ==
                                                    AppLanguage.tr;
                                                final confirmed =
                                                    await showGothicConfirmDialog(
                                                  context,
                                                  title: tr
                                                      ? 'Öğeyi Sil'
                                                      : 'Delete Item',
                                                  content: tr
                                                      ? '${entryName(context, entry)} öğesini katalogdan silmek istediğinize emin misiniz?'
                                                      : 'Are you sure you want to delete ${entryName(context, entry)} from catalog?',
                                                );
                                                if (confirmed) {
                                                  deleteCatalogEntry(
                                                      entry.id);
                                                }
                                              },
                                            ),
                                            SizedBox(width: isMobile ? 2 : 4),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                  ],
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: isMobile ? 24 : 40,
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
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.1),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${t(context, 'editingEntry')}: ${entry.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(),
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
                            color: _activeTab == 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: _activeTab == 1
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                  final isPending = report.status == ReportStatus.open ||
                      report.status == ReportStatus.reviewing;
                  return _activeTab == 0 ? isPending : !isPending;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.report_gmailerrorred_outlined,
                    title: tr ? 'Rapor yok' : 'No reports',
                    body: tr
                        ? 'Bu sekmede görüntülenecek rapor bulunamadı.'
                        : 'No reports found to display in this tab.',
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

Future<ResolvedReportDetails> _resolveReportDetails(
    BuildContext context, UserReport report) async {
  String reporterName = '...';
  String reportedName = '...';
  String contentText = '...';

  // 1. Raporlayan Kullanıcı adını çöz
  try {
    final repDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(report.reporterId)
        .get();
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
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(report.targetId)
            .get();
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
        final doc = await FirebaseFirestore.instance
            .collection('comments')
            .doc(report.targetId)
            .get();
        if (doc.exists) {
          final text = doc.data()?['text'] as String? ?? '';
          final authorId = doc.data()?['userId'] as String? ?? '';
          contentText = AppLanguageScope.languageOf(context) == AppLanguage.tr
              ? 'Yorum: "$text"'
              : 'Comment: "$text"';

          if (authorId.isNotEmpty) {
            final authDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(authorId)
                .get();
            if (authDoc.exists) {
              reportedName =
                  authDoc.data()?['username'] as String? ?? 'Collector';
            } else {
              reportedName = 'ID: $authorId';
            }
          }
        } else {
          contentText = 'ID: ${report.targetId}';
        }
        break;
      case ReportTargetType.catalogEntry:
        final doc = await FirebaseFirestore.instance
            .collection('items')
            .doc(report.targetId)
            .get();
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
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.dividerColor,
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.cardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportReasonLabel(context, report.reason),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final d = snapshot.data!;
                          return RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: GoogleFonts.outfit().fontFamily,
                                color: theme.colorScheme.onSurface,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: tr ? 'Raporlayan: ' : 'Reporter: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary),
                                ),
                                TextSpan(text: '@${d.reporterName}\n'),
                                TextSpan(
                                  text: tr ? 'Raporlanan: ' : 'Reported: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary),
                                ),
                                TextSpan(
                                  text: d.reportedName.startsWith('@') ||
                                          d.reportedName.startsWith('ID:') ||
                                          d.reportedName == 'System / Catalog'
                                      ? '${d.reportedName}\n'
                                      : '@${d.reportedName}\n',
                                ),
                                TextSpan(
                                  text: tr ? 'İçerik: ' : 'Content: ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${d.contentText}\n'),
                                TextSpan(
                                  text: tr ? 'Zaman: ' : 'Time: ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: d.formattedTime),
                                if (report.details.trim().isNotEmpty) ...[
                                  const TextSpan(text: '\n'),
                                  TextSpan(
                                    text: tr ? 'Detay: ' : 'Details: ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: report.details.trim(),
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic),
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
                      side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: theme.colorScheme.onSurface, size: 22),
                      tooltip: tr ? 'İşlemler' : 'Actions',
                      onSelected: (value) async {
                        final tr = AppLanguageScope.languageOf(context) ==
                            AppLanguage.tr;
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
                              updateReportStatus(
                                  report.id, ReportStatus.reviewing);
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
                              updateReportStatus(
                                  report.id, ReportStatus.dismissed);
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
                              updateReportStatus(
                                  report.id, ReportStatus.resolved);
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
                              Icon(Icons.open_in_new_rounded,
                                  size: 18, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 8),
                              Text(t(context, 'openTarget')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reviewing',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 18, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 8),
                              Text(t(context, 'markReviewing')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'dismissed',
                          child: Row(
                            children: [
                              Icon(Icons.block_outlined,
                                  size: 18, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 8),
                              Text(t(context, 'dismissReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Row(
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 18, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 8),
                              Text(t(context, 'resolveReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: theme.colorScheme.onSurface),
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
                                Icon(Icons.delete_forever_rounded,
                                    size: 18, color: theme.colorScheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  tr ? 'İçeriği İmha Et' : 'Destroy Content',
                                  style:
                                      TextStyle(color: theme.colorScheme.error),
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
    final color = isFirebaseReady
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;
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

class AdminUserSearchCard extends StatefulWidget {
  const AdminUserSearchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onUserSelected,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<AppUser> onUserSelected;

  @override
  State<AdminUserSearchCard> createState() => _AdminUserSearchCardState();
}

class _AdminUserSearchCardState extends State<AdminUserSearchCard> {
  final _searchController = TextEditingController();
  List<AppUser> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final res = await socialRepository.searchUsers(query);
      setState(() {
        _results = res;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arama hatası: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: widget.iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => _runSearch(),
              style: GoogleFonts.outfit(),
              decoration: InputDecoration(
                hintText: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Kullanıcı adı ara...'
                    : 'Search username...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary)),
              ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? const Icon(Icons.person_rounded, size: 16)
                            : null,
                      ),
                      title: Text(
                        '@${user.username}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user.displayName),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        widget.onUserSelected(user);
                        _searchController.clear();
                        setState(() {
                          _results = [];
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomWarningForm extends StatefulWidget {
  const _CustomWarningForm({
    required this.userId,
    required this.onSent,
  });

  final String userId;
  final VoidCallback onSent;

  @override
  State<_CustomWarningForm> createState() => _CustomWarningFormState();
}

class _CustomWarningFormState extends State<_CustomWarningForm> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await notificationRepository.sendCustomNotification(
        userId: widget.userId,
        title: title,
        body: body,
      );
      widget.onSent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          style: const TextStyle(fontFamily: 'Outfit'),
          decoration: InputDecoration(
            labelText: tr ? 'Başlık' : 'Title',
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyController,
          style: const TextStyle(fontFamily: 'Outfit'),
          decoration: InputDecoration(
            labelText: tr ? 'İçerik/Mesaj' : 'Message Body',
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(tr ? 'Gönder' : 'Send'),
        ),
      ],
    );
  }
}

class AdminMonetizationCard extends StatefulWidget {
  const AdminMonetizationCard({super.key});

  @override
  State<AdminMonetizationCard> createState() => _AdminMonetizationCardState();
}

class _AdminMonetizationCardState extends State<AdminMonetizationCard> {
  final _formKey = GlobalKey<FormState>();

  final _monthlyPriceController = TextEditingController();
  final _yearlyPriceController = TextEditingController();
  final _coinsPack1PriceController = TextEditingController();
  final _coinsPack2PriceController = TextEditingController();
  final _coinsPack3PriceController = TextEditingController();

  final _coinsPack1CoinsController = TextEditingController();
  final _coinsPack2CoinsController = TextEditingController();
  final _coinsPack3CoinsController = TextEditingController();

  final _campaignTextTrController = TextEditingController();
  final _campaignTextEnController = TextEditingController();
  final _proMonthlyOldPriceController = TextEditingController();
  final _proYearlyOldPriceController = TextEditingController();
  final _campaignTitleTrController = TextEditingController();
  final _campaignTitleEnController = TextEditingController();

  DateTime? _campaignEndTime;
  bool _isCampaignActive = false;
  double _coinMultiplier = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('monetization')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _monthlyPriceController.text =
              data['proMonthlyPriceText'] as String? ?? '₺19.99';
          _yearlyPriceController.text =
              data['proYearlyPriceText'] as String? ?? '₺199.99';
          _coinsPack1PriceController.text =
              data['coinsPack1Price'] as String? ?? '₺19.99';
          _coinsPack2PriceController.text =
              data['coinsPack2Price'] as String? ?? '₺49.99';
          _coinsPack3PriceController.text =
              data['coinsPack3Price'] as String? ?? '₺99.99';

          _coinsPack1CoinsController.text =
              (data['coinsPack1Amount'] ?? 150).toString();
          _coinsPack2CoinsController.text =
              (data['coinsPack2Amount'] ?? 500).toString();
          _coinsPack3CoinsController.text =
              (data['coinsPack3Amount'] ?? 1200).toString();

          _campaignTextTrController.text =
              data['campaignTextTr'] as String? ?? 'Sınırlı Süre Fırsatı!';
          _campaignTextEnController.text =
              data['campaignTextEn'] as String? ?? 'Limited Time Offer!';
          _proMonthlyOldPriceController.text =
              data['proMonthlyOldPriceText'] as String? ?? '';
          _proYearlyOldPriceController.text =
              data['proYearlyOldPriceText'] as String? ?? '';
          _campaignTitleTrController.text =
              data['campaignTitleTr'] as String? ?? 'Karanlık Fırsat';
          _campaignTitleEnController.text =
              data['campaignTitleEn'] as String? ?? 'Mystic Offer';

          final ts = data['campaignEndTimestamp'] as Timestamp?;
          _campaignEndTime = ts?.toDate();
          _isCampaignActive = data['isCampaignActive'] as bool? ?? false;
          _coinMultiplier = (data['coinMultiplier'] as num?)?.toDouble() ?? 1.0;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _monthlyPriceController.text = '₺19.99';
            _yearlyPriceController.text = '₺199.99';
            _coinsPack1PriceController.text = '₺19.99';
            _coinsPack2PriceController.text = '₺49.99';
            _coinsPack3PriceController.text = '₺99.99';
            _coinsPack1CoinsController.text = '150';
            _coinsPack2CoinsController.text = '500';
            _coinsPack3CoinsController.text = '1200';
            _campaignTextTrController.text = 'Sınırlı Süre Fırsatı!';
            _campaignTextEnController.text = 'Limited Time Offer!';
            _proMonthlyOldPriceController.text = '';
            _proYearlyOldPriceController.text = '';
            _campaignTitleTrController.text = 'Karanlık Fırsat';
            _campaignTitleEnController.text = 'Mystic Offer';
            _campaignEndTime = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('monetization')
          .set({
        'proMonthlyPriceText': _monthlyPriceController.text,
        'proYearlyPriceText': _yearlyPriceController.text,
        'coinsPack1Price': _coinsPack1PriceController.text,
        'coinsPack2Price': _coinsPack2PriceController.text,
        'coinsPack3Price': _coinsPack3PriceController.text,
        'coinsPack1Amount':
            int.tryParse(_coinsPack1CoinsController.text) ?? 150,
        'coinsPack2Amount':
            int.tryParse(_coinsPack2CoinsController.text) ?? 500,
        'coinsPack3Amount':
            int.tryParse(_coinsPack3CoinsController.text) ?? 1200,
        'campaignTextTr': _campaignTextTrController.text,
        'campaignTextEn': _campaignTextEnController.text,
        'proMonthlyOldPriceText': _proMonthlyOldPriceController.text,
        'proYearlyOldPriceText': _proYearlyOldPriceController.text,
        'campaignTitleTr': _campaignTitleTrController.text,
        'campaignTitleEn': _campaignTitleEnController.text,
        'campaignEndTimestamp': _campaignEndTime != null
            ? Timestamp.fromDate(_campaignEndTime!)
            : null,
        'isCampaignActive': _isCampaignActive,
        'coinMultiplier': _coinMultiplier,
      });
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Monetizasyon ayarları başarıyla kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _monthlyPriceController.dispose();
    _yearlyPriceController.dispose();
    _coinsPack1PriceController.dispose();
    _coinsPack2PriceController.dispose();
    _coinsPack3PriceController.dispose();
    _coinsPack1CoinsController.dispose();
    _coinsPack2CoinsController.dispose();
    _coinsPack3CoinsController.dispose();
    _campaignTextTrController.dispose();
    _campaignTextEnController.dispose();
    _proMonthlyOldPriceController.dispose();
    _proYearlyOldPriceController.dispose();
    _campaignTitleTrController.dispose();
    _campaignTitleEnController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(
          tr ? 'Fiyatlandırma & Kampanyalar' : 'Pricing & Campaigns',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          tr
              ? 'Pro üyelik, jeton paketleri ve in-app kampanya yönetimi'
              : 'Manage Pro, coin packages and in-app campaigns',
          style: const TextStyle(fontSize: 11),
        ),
        leading: const Icon(Icons.campaign_outlined, color: Colors.amber),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr ? 'Pro Abonelik Fiyatları' : 'Pro Subscription Prices',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: DollDexTheme.teal),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _monthlyPriceController,
                          decoration: InputDecoration(
                            labelText: tr ? 'Aylık Fiyat' : 'Monthly Price',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _yearlyPriceController,
                          decoration: InputDecoration(
                            labelText: tr ? 'Yıllık Fiyat' : 'Yearly Price',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _proMonthlyOldPriceController,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Aylık Eski Fiyat' : 'Monthly Old Price',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _proYearlyOldPriceController,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Yıllık Eski Fiyat' : 'Yearly Old Price',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr
                        ? 'Jeton Paketi Fiyatları & Miktarları'
                        : 'Coin Package Prices & Amounts',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: DollDexTheme.teal),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack1CoinsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 1 (Jeton)' : 'Pack 1 (Coins)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack1PriceController,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 1 (Fiyat)' : 'Pack 1 (Price)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack2CoinsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 2 (Jeton)' : 'Pack 2 (Coins)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack2PriceController,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 2 (Fiyat)' : 'Pack 2 (Price)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack3CoinsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 3 (Jeton)' : 'Pack 3 (Coins)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _coinsPack3PriceController,
                          decoration: InputDecoration(
                            labelText:
                                tr ? 'Paket 3 (Fiyat)' : 'Pack 3 (Price)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr ? 'Kampanya Ayarları' : 'Campaign Settings',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: DollDexTheme.teal),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title:
                        Text(tr ? 'Kampanya Aktif mi?' : 'Is Campaign Active?'),
                    subtitle: Text(tr
                        ? 'Mağazada kampanya bandını gösterir'
                        : 'Shows campaign banner in shop'),
                    value: _isCampaignActive,
                    onChanged: (val) => setState(() => _isCampaignActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tr ? "Jeton Kampanya Çarpanı" : "Coin Campaign Multiplier"}: ${_coinMultiplier.toStringAsFixed(1)}x',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: _coinMultiplier,
                    min: 1.0,
                    max: 3.0,
                    divisions: 4,
                    label: '${_coinMultiplier.toStringAsFixed(1)}x',
                    onChanged: (val) => setState(() => _coinMultiplier = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _campaignTitleTrController,
                          decoration: InputDecoration(
                            labelText: tr
                                ? 'Kampanya Başlığı (Türkçe)'
                                : 'Campaign Title (Turkish)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _campaignTitleEnController,
                          decoration: InputDecoration(
                            labelText: tr
                                ? 'Kampanya Başlığı (İngilizce)'
                                : 'Campaign Title (English)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '*' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _campaignTextTrController,
                    decoration: InputDecoration(
                      labelText: tr
                          ? 'Kampanya Açıklaması (Türkçe)'
                          : 'Campaign Body (Turkish)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? '*' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _campaignTextEnController,
                    decoration: InputDecoration(
                      labelText: tr
                          ? 'Kampanya Açıklaması (İngilizce)'
                          : 'Campaign Body (English)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? '*' : null,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr
                                    ? 'Kampanya Bitiş Süresi'
                                    : 'Campaign End Date & Time',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _campaignEndTime == null
                                    ? (tr
                                        ? 'Bitiş Tarihi Seçilmedi (Sınırsız)'
                                        : 'No End Date Selected (Unlimited)')
                                    : _formatDateTime(_campaignEndTime!),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(tr ? 'Tarih Seç' : 'Pick Date'),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _campaignEndTime ??
                                  DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null && mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    _campaignEndTime ?? DateTime.now()),
                              );
                              if (time != null && mounted) {
                                setState(() {
                                  _campaignEndTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                        if (_campaignEndTime != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: Colors.redAccent),
                            onPressed: () =>
                                setState(() => _campaignEndTime = null),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(tr ? 'Ayarları Kaydet' : 'Save Settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPopupAnnouncementCard extends StatefulWidget {
  const AdminPopupAnnouncementCard({super.key});

  @override
  State<AdminPopupAnnouncementCard> createState() =>
      _AdminPopupAnnouncementCardState();
}

class _AdminPopupAnnouncementCardState extends State<AdminPopupAnnouncementCard> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _titleColorController = TextEditingController();
  final _bodyColorController = TextEditingController();
  final _backgroundColorController = TextEditingController();
  final _buttonTextController = TextEditingController();
  final _buttonUrlController = TextEditingController();

  String _selectedIcon = 'announcement';
  bool _isActive = false;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAnnouncement();
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _titleColorController.dispose();
    _bodyColorController.dispose();
    _backgroundColorController.dispose();
    _buttonTextController.dispose();
    _buttonUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAnnouncement() async {
    setState(() => _isLoading = true);
    try {
      final data = await notificationRepository.getPopupAnnouncement();
      if (data != null && mounted) {
        _idController.text = data['id'] as String? ?? '';
        _titleController.text = data['title'] as String? ?? '';
        _bodyController.text = data['body'] as String? ?? '';
        _imageUrlController.text = data['imageUrl'] as String? ?? '';
        _titleColorController.text = data['titleColor'] as String? ?? '';
        _bodyColorController.text = data['bodyColor'] as String? ?? '';
        _backgroundColorController.text = data['backgroundColor'] as String? ?? '';
        _buttonTextController.text = data['buttonText'] as String? ?? '';
        _buttonUrlController.text = data['buttonUrl'] as String? ?? '';
        _selectedIcon = data['iconName'] as String? ?? 'announcement';
        _isActive = data['isActive'] as bool? ?? false;

        final startsAtVal = data['startsAt'];
        final endsAtVal = data['endsAt'];
        if (startsAtVal is Timestamp) _startsAt = startsAtVal.toDate();
        if (endsAtVal is Timestamp) _endsAt = endsAtVal.toDate();
        if (startsAtVal is String) _startsAt = DateTime.tryParse(startsAtVal);
        if (endsAtVal is String) _endsAt = DateTime.tryParse(endsAtVal);
      }
    } catch (e) {
      print('AdminPopupAnnouncementCard: Error loading current popup: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    try {
      final data = {
        'id': _idController.text.trim().isNotEmpty
            ? _idController.text.trim()
            : 'popup-${DateTime.now().millisecondsSinceEpoch}',
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'titleColor': _titleColorController.text.trim(),
        'bodyColor': _bodyColorController.text.trim(),
        'backgroundColor': _backgroundColorController.text.trim(),
        'buttonText': _buttonTextController.text.trim().isNotEmpty
            ? _buttonTextController.text.trim()
            : (tr ? 'Anladım' : 'Got it'),
        'buttonUrl': _buttonUrlController.text.trim(),
        'iconName': _selectedIcon,
        'isActive': _isActive,
        'startsAt': _startsAt != null ? Timestamp.fromDate(_startsAt!) : null,
        'endsAt': _endsAt != null ? Timestamp.fromDate(_endsAt!) : null,
      };

      await notificationRepository.savePopupAnnouncement(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr
                  ? 'Duyuru başarıyla kaydedildi!'
                  : 'Announcement successfully saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr ? 'Hata: $e' : 'Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clear() async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    setState(() => _isLoading = true);
    try {
      await notificationRepository.clearPopupAnnouncement();
      _idController.clear();
      _titleController.clear();
      _bodyController.clear();
      _imageUrlController.clear();
      _titleColorController.clear();
      _bodyColorController.clear();
      _backgroundColorController.clear();
      _buttonTextController.clear();
      _buttonUrlController.clear();
      _startsAt = null;
      _endsAt = null;
      _isActive = false;
      _selectedIcon = 'announcement';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr
                  ? 'Duyuru temizlendi ve kaldırıldı.'
                  : 'Announcement cleared and deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr ? 'Hata: $e' : 'Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(
      BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon,
          size: 20, color: Theme.of(context).colorScheme.primary),
      labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(
          tr ? 'Pop-up Duyuru Yönetimi' : 'Pop-up Announcement Management',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        subtitle: Text(
          tr
              ? 'Uygulama açılışında ekranda görünecek özel duyuruyu ayarlayın'
              : 'Configure custom popup announcement shown at app startup',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title:
                      Text(tr ? 'Duyuru Aktif mi?' : 'Is Announcement Active?'),
                  value: _isActive,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idController,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  decoration: _buildInputDecoration(
                    context,
                    tr
                        ? 'Duyuru Kimliği (ID - Benzersiz)'
                        : 'Announcement ID (Unique)',
                    Icons.fingerprint_rounded,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return tr ? 'ID gerekli' : 'ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Duyuru Başlığı' : 'Announcement Title',
                    Icons.title_rounded,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return tr ? 'Başlık gerekli' : 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Duyuru İçeriği' : 'Announcement Content',
                    Icons.campaign_outlined,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return tr ? 'İçerik gerekli' : 'Content is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Görsel URL (Fotoğraf)' : 'Image URL (Photo)',
                    Icons.image_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedIcon,
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Duyuru Simgesi' : 'Announcement Icon',
                    Icons.star_outline_rounded,
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  items: [
                    DropdownMenuItem(
                        value: 'announcement',
                        child: Text(tr ? 'Duyuru (Kampanya)' : 'Announcement')),
                    DropdownMenuItem(
                        value: 'info', child: Text(tr ? 'Bilgi (Mavi)' : 'Info')),
                    DropdownMenuItem(
                        value: 'warning',
                        child: Text(tr ? 'Uyarı (Sarı)' : 'Warning')),
                    DropdownMenuItem(
                        value: 'star',
                        child: Text(tr ? 'Yıldız / Yeni' : 'Star / New')),
                    DropdownMenuItem(
                        value: 'premium',
                        child: Text(tr ? 'Premium / Pro' : 'Premium / Pro')),
                    DropdownMenuItem(
                        value: 'gift',
                        child: Text(tr ? 'Hediye / Ödül' : 'Gift / Reward')),
                    DropdownMenuItem(
                        value: 'update',
                        child: Text(tr ? 'Güncelleme' : 'Update')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedIcon = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _titleColorController,
                        style:
                            const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        decoration: _buildInputDecoration(
                          context,
                          tr ? 'Başlık Rengi (Hex)' : 'Title Color (Hex)',
                          Icons.color_lens_outlined,
                        ).copyWith(hintText: '#FFFFFF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _bodyColorController,
                        style:
                            const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        decoration: _buildInputDecoration(
                          context,
                          tr ? 'İçerik Rengi (Hex)' : 'Body Color (Hex)',
                          Icons.color_lens_outlined,
                        ).copyWith(hintText: '#E0E0E0'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _backgroundColorController,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  decoration: _buildInputDecoration(
                    context,
                    tr
                        ? 'Arka Plan Rengi (Hex, örn: #1A0D2E)'
                        : 'Background Color (Hex, e.g. #1A0D2E)',
                    Icons.format_color_fill_rounded,
                  ).copyWith(hintText: '#15120F'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buttonTextController,
                        style:
                            const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        decoration: _buildInputDecoration(
                          context,
                          tr ? 'Buton Yazısı' : 'Button Text',
                          Icons.smart_button_rounded,
                        ).copyWith(hintText: tr ? 'Anladım' : 'Got it'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _buttonUrlController,
                        style:
                            const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        decoration: _buildInputDecoration(
                          context,
                          tr ? 'Buton Linki / Rota' : 'Button Link / Route',
                          Icons.link_rounded,
                        ).copyWith(hintText: '/collection veya https://...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  tr
                      ? 'Yayınlanma Zaman Ayarı'
                      : 'Publish Timing Configuration',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          _startsAt == null
                              ? (tr ? 'Başlangıç Seç' : 'Pick Start')
                              : _startsAt!.toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          final dt = await _pickDateTime(context, _startsAt);
                          if (dt != null) {
                            setState(() => _startsAt = dt);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          _endsAt == null
                              ? (tr ? 'Bitiş Seç' : 'Pick End')
                              : _endsAt!.toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          final dt = await _pickDateTime(context, _endsAt);
                          if (dt != null) {
                            setState(() => _endsAt = dt);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_startsAt != null || _endsAt != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          _startsAt = null;
                          _endsAt = null;
                        });
                      },
                      child: Text(tr ? 'Zamanlamayı Kaldır' : 'Clear Timing',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.redAccent)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: Text(tr ? 'Kaydet / Yayınla' : 'Save / Publish',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: Text(tr ? 'Temizle' : 'Clear',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
