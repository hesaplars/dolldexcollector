import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../src/monetization/billing_service.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';
import '../users/profile_setup_repository.dart';
import '../core/app_helpers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildGothicCard({required String title, required List<Widget> children}) {
      final primary = Theme.of(context).colorScheme.primary;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary.withOpacity(isDark ? 0.4 : 0.6),
            width: isDark ? 1.5 : 2.0,
          ),
          color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF130820) : Colors.white),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.0,
                  fontFamily: 'Cinzel',
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget buildGothicRow({
      required BuildContext context,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            children: [
              buildNeonIcon(context, icon, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEC008C),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<ProfileSetupStatus>(
      stream: user != null ? profileSetupRepository.watch(user.uid) : const Stream.empty(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isPro = profile?.isPro == true || profile?.role == 'admin';

        return PageShell(
          title: tr ? 'Ayarlar' : 'Settings',
          subtitle: tr ? 'Hesap ve uygulama ayarları' : 'Account and app settings',
          showBackButton: true,
          child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (user != null)
            buildGothicCard(
              title: tr ? 'Profil Özelleştirme' : 'Profile Customization',
              children: [
                buildGothicRow(
                  context: context,
                  icon: Icons.face_3_outlined,
                  title: tr ? 'Profilini Özelleştir' : 'Customize Your Profile',
                  subtitle: tr
                      ? 'Avatar, Profil Çerçevesi, Profil Rozeti ve Kapak Fotoğrafını değiştir'
                      : 'Change Avatar, Profile Frame, Profile Badge, and Cover Photo',
                  onTap: () => showAvatarStudioModal(context, user.uid),
                ),
                const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
                buildGothicRow(
                  context: context,
                  icon: Icons.alternate_email_rounded,
                  title: tr ? 'Kullanıcı Adı Değiştir' : 'Change Username',
                  subtitle: tr ? 'Benzersiz @kullanıcı_adı belirle' : 'Set your unique @username',
                  onTap: () => showChangeUsernameDialog(context, user.uid),
                ),
                const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
                buildGothicRow(
                  context: context,
                  icon: Icons.workspace_premium_outlined,
                  title: 'DollDex Pro',
                  subtitle: tr ? 'Pro üyelik avantajlarını gör ve satın al' : 'View Pro benefits and purchase',
                  onTap: () => showProSubscriptionModal(context),
                ),
                const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
                buildGothicRow(
                  context: context,
                  icon: Icons.report_gmailerrorred_rounded,
                  title: tr ? 'Raporlarım' : 'My Reports',
                  subtitle: tr ? 'Bildirdiğiniz şikayetleri ve durumlarını görün' : 'View your reported complaints and status',
                  onTap: () => showReportsModal(context, user.uid),
                ),
              ],
            ),
          buildGothicCard(
            title: tr ? 'Arayüz ve Görünüm' : 'Interface & Appearance',
            children: [
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    tr ? 'Site Teması Seçimi' : 'Select Site Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: buildNeonIcon(context, Icons.palette_outlined),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: Theme.of(context).colorScheme.primary,
                  collapsedIconColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: appThemeKeyController,
                      builder: (context, activeThemeKey, _) {
                        final themes = [
                          {'key': 'goth_light', 'nameTr': 'Açık Goth', 'nameEn': 'Light Goth', 'color': DollDexTheme.teal, 'bg': DollDexTheme.paper},
                          {'key': 'goth_dark', 'nameTr': 'Koyu Goth', 'nameEn': 'Dark Goth', 'color': DollDexTheme.teal, 'bg': DollDexTheme.darkPaper},
                          {'key': 'toxic_neon', 'nameTr': 'Zehir Yeşili', 'nameEn': 'Toxic Neon', 'color': const Color(0xFF39FF14), 'bg': const Color(0xFF060D08), 'isPro': true},
                          {'key': 'crimson_blood', 'nameTr': 'Kan Kırmızısı', 'nameEn': 'Crimson Blood', 'color': const Color(0xFFFF073A), 'bg': const Color(0xFF0B0606), 'isPro': true},
                          {'key': 'royal_gold', 'nameTr': 'Asil Altın', 'nameEn': 'Royal Gold', 'color': const Color(0xFFFFD700), 'bg': const Color(0xFF0B0410), 'isPro': true},
                        ];

                        return Column(
                          children: themes.map((tItem) {
                            final themeKey = tItem['key'] as String;
                            final name = tr ? tItem['nameTr'] as String : tItem['nameEn'] as String;
                            final primaryColor = tItem['color'] as Color;
                            final themeIsPro = tItem['isPro'] == true;
                            final isSelected = activeThemeKey == themeKey;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  if (themeIsPro && !isPro) {
                                    showGothicConfirmDialog(
                                      context,
                                      title: tr ? 'DollDex Pro Özelliği' : 'DollDex Pro Feature',
                                      content: tr
                                          ? 'Bu özel renkli gotik temayı kullanabilmek için DollDex Pro üyesi olmalısınız.'
                                          : 'You must be a DollDex Pro member to use this custom colored gothic theme.',
                                      confirmText: tr ? "Pro'ya Geç" : 'Upgrade to Pro',
                                      cancelText: tr ? 'Vazgeç' : 'Cancel',
                                    ).then((confirmed) {
                                      if (confirmed && context.mounted) {
                                        showProSubscriptionModal(context);
                                      }
                                    });
                                  } else {
                                    appThemeKeyController.value = themeKey;
                                    if (user != null) {
                                      profileSetupRepository.saveSelectedTheme(user.uid, themeKey);
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(0.4),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            if (themeIsPro) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.workspace_premium_rounded,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey.withOpacity(0.5),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          buildGothicCard(
            title: tr ? 'Yasal ve Hesap' : 'Legal & Account',
            children: [
              buildGothicRow(
                context: context,
                icon: Icons.privacy_tip_outlined,
                title: t(context, 'privacyPolicy'),
                subtitle: t(context, 'privacyRequired'),
                onTap: () => context.push('/privacy'),
              ),
              const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
              buildGothicRow(
                context: context,
                icon: Icons.description_outlined,
                title: t(context, 'termsOfUse'),
                subtitle: t(context, 'termsRequired'),
                onTap: () => context.push('/terms'),
              ),
              if (user != null) ...[
                const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
                buildGothicRow(
                  context: context,
                  icon: Icons.delete_outline_rounded,
                  title: t(context, 'deleteAccount'),
                  subtitle: t(context, 'deleteRequired'),
                  onTap: () => context.push('/delete-account'),
                ),
              ],
            ],
          ),
          buildGothicCard(
            title: tr ? 'Hakkında' : 'About',
            children: [
              Text(
                tr
                    ? 'DollDex Collector, en sevdiğiniz oyuncak bebek koleksiyonlarını düzenlemek, izlemek ve toplulukla paylaşmak için tasarlanmış bağımsız gotik esintili bir koleksiyoncu uygulamasıdır. Telif hakkı veya lisanslı hiçbir materyal barındırmaz, tamamen jenerik gotik bebek tasarımları içerir.\n\n'
                        'Yeni Karanlık Özellikler:\n'
                        '• Canlı Gotik Bildirim Akışı ile topluluk etkileşimleri.\n'
                        '• Kaydırmalı Hızlı Aksiyonlar ve Toplu Silme mekanizmaları.\n'
                        '• Gelişmiş Gotik Çerçeve Motoru ve Avatar Stüdyosu ile profil özelleştirme.\n'
                        '• Animasyonlu Gotik Açılış Ekranı ve neon gotik motifler.'
                    : 'DollDex Collector is an independent gothic-inspired collector app designed to organize, track, and share your favorite doll collections with the community. It contains no licensed or copyrighted materials and uses only generic gothic doll designs.\n\n'
                        'New Gothic Features:\n'
                        '• Live Gothic Notification Stream for community interactions.\n'
                        '• Swipe Quick Actions and Batch Deletion mechanics.\n'
                        '• Advanced Gothic Frame Engine and Avatar Studio for profile customization.\n'
                        '• Animated Gothic Splash Screen and neon gothic motifs.',
                style: TextStyle(height: 1.4, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                'Version: 1.1.0+2',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold),
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
