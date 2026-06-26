import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../core/app_helpers.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';
import '../notifications/notification_models.dart';

class AnnouncementForm extends StatefulWidget {
  const AnnouncementForm({super.key});

  @override
  State<AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPublishing = false;

  Stream<List<AppNotification>>? _announcementsStream;
  String? _cachedUserId;

  void _initStream() {
    final userId = authService.currentUser?.uid ?? 'local-user';
    if (_announcementsStream == null || _cachedUserId != userId) {
      _cachedUserId = userId;
      _announcementsStream = notificationRepository.watchForUser(userId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(
      BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);

    return InputDecoration(
      labelText: label,
      prefixIcon: buildNeonIcon(context, icon, size: 20),
      alignLabelWithHint: true,
      labelStyle: const TextStyle(fontFamily: 'Outfit'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.dividerColor,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade800,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade800,
          width: 2.0,
        ),
      ),
    );
  }

  Widget _buildGotikButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          title: Text(
            tr ? 'Duyuru Yayınlama Onayı' : 'Publish Announcement Confirmation',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            tr
                ? 'Bu duyuruyu tüm kullanıcılara bildirim olarak göndermek istediğinize emin misiniz?'
                : 'Are you sure you want to publish this announcement to all users as a notification?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                tr ? 'Vazgeç' : 'Cancel',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(tr ? 'Yayınla' : 'Publish'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isPublishing = true);
    try {
      await notificationRepository.publishAnnouncement(title, body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr
                  ? 'Duyuru başarıyla tüm kullanıcılara gönderildi.'
                  : 'Announcement successfully published to all users.',
            ),
          ),
        );
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr ? 'Hata oluştu: $e' : 'An error occurred: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _initStream();
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Card(
      child: ExpansionTile(
        title: Text(
          tr ? 'Duyuru Yayınlama Formu' : 'Announcement Publishing Form',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        subtitle: Text(
          tr
              ? 'Tüm kullanıcılara canlı bildirim olarak gidecek bir duyuru yayınlayın'
              : 'Publish an announcement that will go as a live notification to all users',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Duyuru Başlığı' : 'Announcement Title',
                    Icons.title_rounded,
                  ),
                  textInputAction: TextInputAction.next,
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
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: _buildInputDecoration(
                    context,
                    tr ? 'Duyuru İçeriği' : 'Announcement Content',
                    Icons.campaign_outlined,
                  ),
                  minLines: 3,
                  maxLines: 6,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return tr ? 'İçerik gerekli' : 'Content is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_isPublishing)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildGotikButton(
                    context: context,
                    onPressed: _submitAnnouncement,
                    icon: Icons.send_rounded,
                    label: tr ? 'Duyuruyu Yayınla' : 'Publish Announcement',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            tr ? 'Yayınlanmış Duyurular' : 'Published Announcements',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AppNotification>>(
            stream: _announcementsStream,
            builder: (streamCtx, snapshot) {
              final notifications = snapshot.data ?? [];
              final announcements = notifications
                  .where((n) => n.deepLink.startsWith('/announcement'))
                  .toList();

              // Benzersiz deepLink'lere göre grupla (çift kayıt göstermemek için)
              final uniqueAnnouncements = <String, AppNotification>{};
              for (final ann in announcements) {
                uniqueAnnouncements[ann.deepLink] = ann;
              }
              final list = uniqueAnnouncements.values.toList();

              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    tr
                        ? 'Henüz yayınlanmış duyuru yok.'
                        : 'No announcements published yet.',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (itemCtx, index) {
                  final ann = list[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(ann.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(ann.body),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text(
                                  tr ? 'Duyuruyu Sil' : 'Delete Announcement'),
                              content: Text(tr
                                  ? 'Bu duyuruyu tüm kullanıcılardan silmek istediğinize emin misiniz?'
                                  : 'Are you sure you want to delete this announcement from all users?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, false),
                                    child: Text(tr ? 'İptal' : 'Cancel')),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.redAccent),
                                  child: Text(tr ? 'Sil' : 'Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notificationRepository
                                .deleteAnnouncement(ann.deepLink);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(tr
                                        ? 'Duyuru silindi'
                                        : 'Announcement deleted')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      title: tr ? 'Sistem Duyurusu' : 'System Announcement',
      subtitle: tr
          ? 'Geliştiricilerden önemli güncellemeler'
          : 'Important updates from the developers',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    buildNeonIcon(context, Icons.campaign_outlined, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'Outfit',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(
                    color: Theme.of(context).dividerColor,
                    height: 32,
                    thickness: 1.2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      tr ? 'Anladım' : 'Got it',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
