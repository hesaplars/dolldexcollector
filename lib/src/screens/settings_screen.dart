import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../src/monetization/billing_service.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildGothicCard({required String title, required List<Widget> children}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEC008C).withOpacity(isDark ? 0.4 : 0.6),
            width: isDark ? 1.5 : 2.0,
          ),
          color: isDark ? const Color(0xFF130820) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC008C).withOpacity(isDark ? 0.15 : 0.08),
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

    return PageShell(
      title: tr ? 'Ayarlar' : 'Settings',
      subtitle: tr ? 'Hesap ve uygulama ayarları' : 'Account and app settings',
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
                  title: tr ? 'Avatar & Çerçeve Seçimi' : 'Select Avatar & Frame',
                  subtitle: tr
                      ? 'Gotik bebek avatarını ve Pro çerçeveni ayarla'
                      : 'Set your gothic doll avatar and Pro frame',
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
                  onTap: () => _showProSubscriptionModal(context),
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
  }

  void _showProSubscriptionModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'DollDex Pro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: DollDexTheme.teal,
                      ),
                ),
                const SizedBox(height: 4),
                Text(t(context, 'proSubtitle')),
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'proBenefits'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        FeatureLine(text: tr ? 'Reklamsız Koyu Gotik Deneyim' : 'Ad-Free Dark Gothic Experience'),
                        FeatureLine(text: tr ? '12 Özel Gotik Bebek Avatarı' : '12 Exclusive Gothic Doll Avatars'),
                        FeatureLine(text: tr ? '12 Premium Gotik Profil Kapak Fotoğrafı' : '12 Premium Gothic Cover Photos'),
                        FeatureLine(text: tr ? '12 Gotik Profil Çerçevesi (Sarmaşık, Yarasa, Örümcek Ağı)' : '12 Gothic Profile Frames (Ivy, Bats, Webs)'),
                        FeatureLine(text: tr ? 'Gelişmiş Koleksiyon İstatistikleri ve Analizler' : 'Advanced Collection Stats & Analytics'),
                        FeatureLine(text: tr ? 'Daha Geniş Profil Vitrini' : 'Expanded Profile Showcase'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PriceOptionCard(
                        title: t(context, 'monthly'),
                        price: t(context, 'playBilling'),
                        subtitle: t(context, 'serverVerified'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PriceOptionCard(
                        title: t(context, 'yearly'),
                        price: t(context, 'playBilling'),
                        subtitle: t(context, 'bestCollectors'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      const billing = BillingService();
                      await billing.buySubscription(BillingService.proMonthlyProductId);
                    } catch (error) {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(tr ? 'Google Play Uyarısı' : 'Google Play Warning'),
                          content: Text(
                            tr
                                ? 'Google Play Billing entegrasyonu Google Play Console kurulumundan sonra aktif olacaktır.'
                                : 'Google Play Billing will be enabled after Google Play Console setup.',
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Tamam'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  label: Text(t(context, 'connectBilling')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PriceOptionCard extends StatelessWidget {
  const PriceOptionCard({
    required this.title,
    required this.price,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String price;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? DollDexTheme.darkLine
              : DollDexTheme.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(price),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
