import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../main.dart';
import '../core/app_language.dart';
import '../core/local_storage_helper.dart';
import '../notifications/notification_models.dart';
import '../social/social_models.dart';
import '../users/profile_setup_repository.dart';
import '../core/url_launcher_helper.dart';
import '../core/web_image_helper.dart';
import 'doll_widgets.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({required this.child, super.key});

  final Widget child;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<ProfileSetupStatus>? _profileSubscription;
  bool _profileComplete = false;
  bool _isAdmin = false;
  bool _isPro = false;
  bool _profileLoaded = false;
  String _avatarId = '';
  String _avatarFrameColor = '';
  String? _watchedUserId;
  bool _isBanned = false;
  DateTime? _banUntil;
  DateTime? _lastDailyClaim;

  AppNotification? _currentHudNotification;
  bool _showHudBanner = false;
  Timer? _hudTimer;
  final Set<String> _shownNotificationIds = {};
  bool _isFirstNotificationsLoad = true;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  int _unreadNotificationsCount = 0;
  StreamSubscription<List<ChatThread>>? _chatThreadsSubscription;
  StreamSubscription<List<String>>? _deletedThreadsSubscription;
  List<ChatThread> _currentThreads = [];
  List<String> _deletedThreadIds = [];
  int _unreadDMsCount = 0;
  StreamSubscription<DocumentSnapshot>? _monetizationSubscription;
  static bool _campaignPopupShown = false;
  bool _popupAnnouncementChecked = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = authService.authStateChanges.listen((user) {
      _updateProfileSubscription(user);
    });
    _updateProfileSubscription(authService.currentUser);
  }

  Widget _buildNeonTopIcon(IconData icon) {
    return Icon(
      icon,
      color: DollDexTheme.cocoa,
      size: 24,
    );
  }

  IconData _notificationTypeIcon(AppNotificationType type) {
    return switch (type) {
      AppNotificationType.comment => Icons.comment_outlined,
      AppNotificationType.like => Icons.favorite_border_rounded,
      AppNotificationType.follow => Icons.person_add_outlined,
      AppNotificationType.friendRequest => Icons.people_outline_rounded,
      AppNotificationType.message => Icons.mail_outline_rounded,
      AppNotificationType.moderation => Icons.gavel_rounded,
      AppNotificationType.pro => Icons.workspace_premium_outlined,
    };
  }

  Widget _buildNeonIcon(BuildContext context, IconData icon,
      {double size = 24}) {
    return Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
  }

  bool get _isCurrentlyBanned {
    if (_isBanned) return true;
    if (_banUntil != null) {
      if (_banUntil!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  void _showInfoModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: isDark ? DollDexTheme.darkPanel : DollDexTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: DollDexTheme.teal, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr
                              ? 'DollDex Rehberi & Yasal Bilgiler'
                              : 'DollDex Guide & Legal Info',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YASAL UYARI / LEGAL DISCLAIMER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TR: DollDex, ticari amaç gütmeyen bir hayran sitesidir. Monster High ve ilgili tüm ticari markalar Mattel, Inc. şirketine aittir. Bu site hiçbir şekilde Mattel, Inc. ile ilişkili değildir veya sponsorluğunda değildir.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'EN: DollDex is a non-commercial, fan-made site. Monster High and all related trademarks are owned by Mattel, Inc. This site is in no way affiliated with or sponsored by Mattel, Inc.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr ? 'KULLANIM REHBERİ' : 'USER GUIDE',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      letterSpacing: 0,
                      color: DollDexTheme.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGuideSection(
                    title: tr ? '1. Katalog ve Arama' : '1. Catalog & Search',
                    content: tr
                        ? 'Geniş Monster High kataloğumuzda dilediğiniz bebeği arayabilir, seriye ve yıla göre filtreleme yapabilirsiniz. Bebeklerin detay sayfalarından çıkış yıllarını, aksesuarlarını, kutu görsellerini ve koleksiyoner yorumlarını inceleyebilirsiniz.'
                        : 'Search for any doll in our comprehensive Monster High catalog, filter by series and release year. Inspect release years, accessories, box arts, and collector reviews on the detail pages.',
                    icon: Icons.search_rounded,
                    isDark: isDark,
                  ),
                  _buildGuideSection(
                    title: tr
                        ? '2. Koleksiyon & İstek Listesi Yönetimi'
                        : '2. Collection & Wishlist Management',
                    content: tr
                        ? 'Katalogtaki bebeklerin yanındaki butonları kullanarak bunları Koleksiyonunuza ("Sahibim"), İstek Listenize ("Arıyorum") veya "Yolda" statüsüne ekleyebilirsiniz. Koleksiyonunuzdaki bebeklerin durumlarını (Kutulu/Kutusuz) seçebilir ve onlara özel notlar ekleyebilirsiniz.'
                        : 'Use the action buttons on doll cards to add them to your Collection ("Owned"), Wishlist ("Looking For"), or "On the Way" lists. Track conditions (In Box/Loose) and write custom private notes.',
                    icon: Icons.auto_awesome_motion_rounded,
                    isDark: isDark,
                  ),
                  _buildGuideSection(
                    title: tr
                        ? '3. Vitrin Sınırları & PRO Üyelik'
                        : '3. Showcase Limits & PRO Membership',
                    content: tr
                        ? 'Standart üyeler koleksiyonlarında ve istek listelerinde belirli bir sayıda bebek sergileyebilirler. PRO (Premium) üyeliğe geçerek bu sınırları tamamen kaldırabilir, reklamları kapatabilir, özel profil çerçevelerine erişebilir ve her ay ekstra sohbet jetonları kazanabilirsiniz.'
                        : 'Standard members have limits on how many dolls they can display. Upgrade to PRO (Premium) to unlock unlimited slots, disable ads, access exclusive avatar frames, and receive monthly chat coins.',
                    icon: Icons.stars_rounded,
                    isDark: isDark,
                  ),
                  _buildGuideSection(
                    title: tr
                        ? '4. Genel Sohbet & Öge Paylaşımı'
                        : '4. Global Chat & Item Sharing',
                    content: tr
                        ? 'Sohbet alanında diğer koleksiyonerler ile gerçek zamanlı yazışabilir, "+" butonuna basarak Katalogtan veya kendi Koleksiyonunuzdan bebekleri minyatür kartlar şeklinde sohbete gönderebilirsiniz. Gönderilen kartlara tıklayan diğer kullanıcılar alttan kayan detay penceresinde bebeği inceleyebilirler.'
                        : 'Chat with other collectors in real-time, press the "+" button to select dolls from the Catalog or your own Collection, and share them as miniature cards. Others can tap these cards to view details instantly.',
                    icon: Icons.chat_bubble_outline_rounded,
                    isDark: isDark,
                  ),
                  _buildGuideSection(
                    title: tr ? '5. Jeton (Coin) Sistemi' : '5. Coin System',
                    content: tr
                        ? 'Genel sohbette mesaj göndermek ve öge paylaşmak için jeton kullanılır. Sol üstteki Hediye Kutusu simgesiyle günlük ücretsiz jetonlarınızı toplayabilir, video reklamları izleyerek jeton kazanabilir ya da Mağazadan PRO paketleri satın alarak jeton bakiyenizi doldurabilirsiniz.'
                        : 'Coins are used to send messages and share items in global chat. Collect free daily coins from the Gift Box on the top-left, watch short video ads for coins, or top up your balance from the Shop.',
                    icon: Icons.monetization_on_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuideSection({
    required String title,
    required String content,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DollDexTheme.teal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: DollDexTheme.teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumNavigationBar(
    int selectedIndex,
    List<NavigationDestination> destinations,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? DollDexTheme.darkPanel : const Color(0xFFFFF4DC),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.24 : 0.13),
                blurRadius: 18,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                final path = _pathForIndex(index);
                _goGuarded(path);
              },
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCurrentlyBanned) {
      return GothicAccessDeniedScreen(
        isPermanent: _isBanned,
        banUntil: _banUntil,
      );
    }
    final location = GoRouterState.of(context).uri.path;
    const mainTabs = {'/', '/collection', '/messages', '/user_search', '/social', '/admin'};
    final showTopBackButton = !mainTabs.contains(location) &&
        (GoRouter.of(context).canPop() ||
            Navigator.of(context).canPop() ||
            location == '/profile' ||
            location.startsWith('/u/') ||
            location.startsWith('/users/')) &&
        !location.startsWith('/catalog/') &&
        !location.startsWith('/i/') &&
        !location.startsWith('/collection/entry/') &&
        !location.startsWith('/c/') &&
        !(location == '/' &&
            GoRouterState.of(context).uri.queryParameters.containsKey('q'));
    final selectedIndex = (() {
      var activePath = location;
      if (activePath.startsWith('/consent')) {
        final uri = GoRouterState.of(context).uri;
        final fromPath = uri.queryParameters['from'];
        if (fromPath != null && fromPath.isNotEmpty) {
          activePath = Uri.parse(fromPath).path;
        }
      }
      return switch (activePath) {
        '/collection' => 1,
        '/messages' => 2,
        '/user_search' => 3,
        '/social' => 4,
        '/admin' => _isAdmin ? 5 : 0,
        _ => 0,
      };
    })();
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final destinations = [
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 0 ? 1.0 : 0.45,
          child: Image.asset(
            'assets/icons/nav_catalog.png',
            width: 28,
            height: 28,
            color: selectedIndex == 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
        label: t(context, 'catalog'),
      ),
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 1 ? 1.0 : 0.45,
          child: Image.asset(
            'assets/icons/nav_collection.png',
            width: 28,
            height: 28,
            color: selectedIndex == 1
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
        label: t(context, 'collection'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _unreadDMsCount > 0,
          label: Text('$_unreadDMsCount'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Opacity(
            opacity: selectedIndex == 2 ? 1.0 : 0.45,
            child: Image.asset(
              'assets/icons/nav_messages.png',
              width: 28,
              height: 28,
              color: selectedIndex == 2
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        label: tr ? 'Mesajlarım' : 'Messages',
      ),
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 3 ? 1.0 : 0.45,
          child: Icon(
            Icons.person_search_rounded,
            size: 28,
            color: selectedIndex == 3
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
        label: tr ? 'Ara' : 'Search',
      ),
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 4 ? 1.0 : 0.45,
          child: Image.asset(
            'assets/icons/nav_social.png',
            width: 28,
            height: 28,
            color: selectedIndex == 4
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
        label: tr ? 'Sohbet' : 'Chat',
      ),
      if (_isAdmin)
        NavigationDestination(
          icon: Opacity(
            opacity: selectedIndex == 5 ? 1.0 : 0.45,
            child: Image.asset(
              'assets/icons/nav_admin.png',
              width: 28,
              height: 28,
              color: selectedIndex == 5
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
            ),
          ),
          label: t(context, 'admin'),
        ),
    ];

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 950;

    final mainScaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90 + MediaQuery.of(context).padding.top),
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            bottom: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _goGuarded('/'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(context, 'appName').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D2B8)
                                : DollDexTheme.ink,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          tr
                              ? 'Online Bebek Koleksiyonu'
                              : 'Online Doll Collection',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D2B8).withOpacity(0.72)
                                : DollDexTheme.cocoa.withOpacity(0.72),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (showTopBackButton)
                      IconButton(
                        tooltip: AppLanguageScope.languageOf(context) ==
                                AppLanguage.tr
                            ? 'Geri'
                            : 'Back',
                        icon:
                            _buildNeonTopIcon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          final router = GoRouter.of(context);
                          final fromPath = GoRouterState.of(context)
                              .uri
                              .queryParameters['from'];
                          if (fromPath != null && fromPath.isNotEmpty) {
                            router.go(fromPath);
                            return;
                          }
                          if (router.canPop()) {
                            router.pop();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            if (location.startsWith('/u/') ||
                                location.startsWith('/users/')) {
                              router.go('/user_search');
                            } else {
                              router.go('/');
                            }
                          }
                        },
                      )
                    else ...[
                      DailyRewardGiftWidget(
                        currentUser: authService.currentUser,
                        lastDailyClaim: _lastDailyClaim,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: AppLanguageScope.languageOf(context) ==
                                AppLanguage.tr
                            ? 'Kullanım Rehberi & Bilgi'
                            : 'User Guide & Info',
                        icon: _buildNeonTopIcon(Icons.info_outline_rounded),
                        onPressed: () => _showInfoModal(context),
                      ),
                    ],
                    const Spacer(),
                    ValueListenableBuilder<AppLanguage>(
                      valueListenable: appLanguageController,
                      builder: (context, language, _) {
                        return IconButton(
                          tooltip: language == AppLanguage.tr
                              ? 'Change language'
                              : 'Dili değiştir',
                          icon: _buildNeonTopIcon(Icons.translate_rounded),
                          onPressed: () {
                            final nextLang = language == AppLanguage.tr
                                ? AppLanguage.en
                                : AppLanguage.tr;
                            appLanguageController.setLanguage(nextLang);
                          },
                        );
                      },
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: appThemeKeyController,
                      builder: (context, themeKey, _) {
                        final isDark = themeKey != 'goth_light';
                        return IconButton(
                          tooltip: t(context, 'theme'),
                          onPressed: () {
                            final nextTheme =
                                isDark ? 'goth_light' : 'goth_dark';
                            appThemeKeyController.value = nextTheme;
                            final currentUser = authService.currentUser;
                            if (currentUser != null) {
                              profileSetupRepository.saveSelectedTheme(
                                  currentUser.uid, nextTheme);
                            }
                          },
                          icon: _buildNeonTopIcon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip:
                          AppLanguageScope.languageOf(context) == AppLanguage.tr
                              ? 'Mağaza / Jeton Al'
                              : 'Shop / Buy Coins',
                      icon: _buildNeonTopIcon(Icons.storefront),
                      onPressed: () => showProSubscriptionModal(context),
                    ),
                    Badge(
                      isLabelVisible: _unreadNotificationsCount > 0,
                      label: Text('$_unreadNotificationsCount'),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: IconButton(
                        tooltip: t(context, 'notifications'),
                        onPressed: () => showNotificationsModal(context),
                        icon: _buildNeonTopIcon(
                            Icons.notifications_active_rounded),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 4),
                      child: InkWell(
                        onTap: () => _goGuarded(
                            '/profile?from=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
                            push: true),
                        borderRadius: BorderRadius.circular(20),
                        child: buildAvatarHelper(
                          context,
                          authService.currentUser != null ? _avatarId : '',
                          authService.currentUser != null
                              ? _avatarFrameColor
                              : '',
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          widget.child,
          if (_currentHudNotification != null)
            _buildHudBanner(_currentHudNotification!),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isPro)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: GothicAdBannerHorizontal(),
                  ),
                _buildPremiumNavigationBar(selectedIndex, destinations),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isPro)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: GothicAdBannerHorizontal(),
                  ),
                _buildPremiumNavigationBar(selectedIndex, destinations),
              ],
            ),
    );

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        if (location != '/' && location != '/splash') {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            router.go('/');
          }
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Uygulamadan çıkılsın mı?'),
            content: const Text('DollDex Collector kapatılsın mı?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Çık'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            const Positioned.fill(
              child: GothicPageBackgroundWidget(),
            ),
            if (isDesktop && !_isPro)
              Positioned.fill(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: GothicAdBannerVertical(
                          title: 'SPONSOR',
                          subtitle: 'DollDex Shop',
                          description:
                              'Karanlık ve gizemli gotik bebekler, aksesuarlar ve nadide parçalar burada!',
                          promoCode: 'GOTHIC20',
                          icon: Icons.auto_awesome_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 650,
                        child: mainScaffold,
                      ),
                      const SizedBox(width: 8),
                      const Center(
                        child: GothicAdBannerVertical(
                          title: 'KULÜP',
                          subtitle: 'Vampire Guild',
                          description:
                              'Koleksiyonerler Kulübü\'ne katılın, özel etkinlikleri ve takas fırsatlarını kaçırmayın!',
                          promoCode: 'VAMP10',
                          icon: Icons.nights_stay_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned.fill(
                child: isDesktop
                    ? Center(
                        child: SizedBox(
                          width: 650,
                          child: mainScaffold,
                        ),
                      )
                    : mainScaffold,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _chatThreadsSubscription?.cancel();
    _deletedThreadsSubscription?.cancel();
    _monetizationSubscription?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }

  void _updateProfileSubscription(User? user) {
    if (user?.uid == _watchedUserId) {
      return;
    }

    _profileSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _chatThreadsSubscription?.cancel();
    _deletedThreadsSubscription?.cancel();
    _monetizationSubscription?.cancel();
    _watchedUserId = user?.uid;
    _profileComplete = user == null;
    _isAdmin = false;
    _isPro = false;
    _profileLoaded = false;
    _avatarId = '';
    _avatarFrameColor = '';
    _isBanned = false;
    _banUntil = null;
    _lastDailyClaim = null;
    _isFirstNotificationsLoad = true;
    _shownNotificationIds.clear();
    _unreadNotificationsCount = 0;
    _unreadDMsCount = 0;
    _currentThreads = [];
    _deletedThreadIds = [];

    if (user == null) {
      _campaignPopupShown = false;
      _profileLoaded = true;
      appThemeKeyController.value = 'goth_dark';
      if (mounted) {
        setState(() {});
      }
      _checkAndShowPopupAnnouncement();
      return;
    }

    _monetizationSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('monetization')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null) {
        _checkAndShowCampaign(data);
      }
    }, onError: (err) {
      print('AppScaffold: Error watching monetization settings: $err');
    });

    _profileSubscription =
        profileSetupRepository.watch(user.uid).listen((status) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileComplete = status.isComplete;
        _isAdmin = status.role == 'admin';
        _isPro = status.isPro || status.role == 'admin';
        _avatarId = status.avatarId;
        _avatarFrameColor = status.avatarFrameColor;
        _isBanned = status.isBanned;
        _banUntil = status.banUntil;
        _lastDailyClaim = status.lastDailyClaim;
        _profileLoaded = true;
      });
      if (status.selectedTheme.isNotEmpty &&
          appThemeKeyController.value != status.selectedTheme) {
        appThemeKeyController.value = status.selectedTheme;
      }
      _checkAndShowPopupAnnouncement();
    }, onError: (err) {
      print('AppScaffold: Error watching profile: $err');
      if (mounted) {
        setState(() {
          _profileLoaded = true;
        });
        _checkAndShowPopupAnnouncement();
      }
    });

    _notificationsSubscription =
        notificationRepository.watchForUser(user.uid).listen((notifications) {
      if (!mounted) {
        return;
      }
      _onNotificationsUpdated(notifications);
    }, onError: (err) {
      print('AppScaffold: Error watching notifications: $err');
    });

    _chatThreadsSubscription =
        socialRepository.watchChatThreads(user.uid).listen((threads) {
      _currentThreads = threads;
      _recalculateUnreadDMsCount(user.uid);
    }, onError: (err) {
      print('AppScaffold: Error watching chat threads: $err');
    });

    _deletedThreadsSubscription =
        socialRepository.watchDeletedThreads(user.uid).listen((deletedIds) {
      _deletedThreadIds = deletedIds;
      _recalculateUnreadDMsCount(user.uid);
    }, onError: (err) {
      print('AppScaffold: Error watching deleted threads: $err');
    });

    // Invoke global load function in main.dart
    loadCollectionForCurrentUser();
  }

  void _recalculateUnreadDMsCount(String myUid) async {
    final readTimesRaw = await LocalStorage.getString('last_read_times');
    Map<String, String> readTimes = {};
    if (readTimesRaw != null) {
      try {
        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
      } catch (_) {}
    }

    int unreadCount = 0;
    for (final thread in _currentThreads) {
      if (_deletedThreadIds.contains(thread.id)) continue;
      if (thread.lastMessageSenderId == myUid) continue;
      if (thread.lastMessagePreview.isEmpty) continue;

      final lastReadStr = readTimes[thread.id];
      if (lastReadStr == null) {
        unreadCount++;
        continue;
      }
      final lastRead = DateTime.tryParse(lastReadStr);
      if (lastRead == null) {
        unreadCount++;
        continue;
      }
      if (thread.updatedAt != null && thread.updatedAt!.isAfter(lastRead)) {
        unreadCount++;
        continue;
      }
    }

    if (mounted) {
      setState(() {
        _unreadDMsCount = unreadCount;
      });
    }
  }

  void _onNotificationsUpdated(List<AppNotification> notifications) {
    final unread = notifications.where((n) => !n.isRead).toList();
    if (mounted) {
      setState(() {
        _unreadNotificationsCount = unread.length;
      });
    }
    if (_isFirstNotificationsLoad) {
      _isFirstNotificationsLoad = false;
      for (final n in unread) {
        _shownNotificationIds.add(n.id);
      }
      return;
    }
    for (final notification in unread) {
      if (!_shownNotificationIds.contains(notification.id)) {
        _shownNotificationIds.add(notification.id);
        _triggerHudBanner(notification);
      }
    }
  }

  void _triggerHudBanner(AppNotification notification) {
    _hudTimer?.cancel();
    setState(() {
      _currentHudNotification = notification;
      _showHudBanner = true;
    });

    _hudTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showHudBanner = false;
        });
      }
    });
  }

  Widget _buildHudBanner(AppNotification notification) {
    final topPadding = MediaQuery.of(context).padding.top + 8;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: Curves.fastOutSlowIn,
      top: _showHudBanner ? topPadding : -120,
      left: 12,
      right: 12,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showHudBanner = false;
          });
          notificationRepository.markRead(notification.id);
          if (notification.deepLink.isNotEmpty) {
            context.push(notification.deepLink);
          }
        },
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNeonIcon(
                    context, _notificationTypeIcon(notification.type),
                    size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  onPressed: () {
                    setState(() {
                      _showHudBanner = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pathForIndex(int index) {
    return switch (index) {
      1 => '/collection',
      2 => '/messages',
      3 => '/user_search',
      4 => '/social',
      5 => _isAdmin ? '/admin' : '/',
      _ => '/',
    };
  }

  void _goGuarded(String path, {bool push = false}) {
    final user = authService.currentUser;
    if (user == null) {
      final uri = Uri.parse(path);
      final cleanPath = uri.path;
      final isAllowed = cleanPath == '/' ||
          cleanPath == '/collection' ||
          cleanPath.startsWith('/i/') ||
          cleanPath.startsWith('/c/') ||
          cleanPath == '/privacy' ||
          cleanPath == '/terms' ||
          cleanPath == '/splash' ||
          cleanPath == '/consent' ||
          cleanPath == '/announcement' ||
          cleanPath.startsWith('/catalog/') ||
          cleanPath.startsWith('/collection/entry/');
      if (!isAllowed) {
        push ? context.push('/consent') : context.go('/consent');
        return;
      }
    }

    final allowedWithoutProfile = path == '/profile' ||
        path == '/settings' ||
        path == '/privacy' ||
        path == '/terms' ||
        path == '/delete-account';
    if (user != null && !_profileComplete && !allowedWithoutProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'completeProfileRequired'))),
      );
      push ? context.push('/profile') : context.go('/profile');
      return;
    }

    if (path == '/admin' && !_isAdmin) {
      push ? context.push('/profile') : context.go('/profile');
      return;
    }

    push ? context.push(path) : context.go(path);
  }

  void _checkAndShowCampaign(Map<String, dynamic> data) {
    if (_campaignPopupShown) return;
    final user = authService.currentUser;
    if (user == null) return;

    final isGoogleUser =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (!isGoogleUser) return;

    final rawCampaignActive = data['isCampaignActive'] as bool? ?? false;
    final campaignEndTimestamp = data['campaignEndTimestamp'] as Timestamp?;
    final isCampaignExpired = campaignEndTimestamp != null &&
        DateTime.now().isAfter(campaignEndTimestamp.toDate());
    final isCampaignActive = rawCampaignActive && !isCampaignExpired;
    if (!isCampaignActive) return;

    _campaignPopupShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showCampaignModal(data);
    });
  }

  void _showCampaignModal(Map<String, dynamic> data) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final campaignTitle = tr
        ? (data['campaignTitleTr'] as String? ?? 'KARANLIK FIRSAT')
        : (data['campaignTitleEn'] as String? ?? 'MYSTIC OFFER');
    final campaignText = tr
        ? (data['campaignTextTr'] as String? ?? 'Sınırlı Süre Fırsatı!')
        : (data['campaignTextEn'] as String? ?? 'Limited Time Offer!');
    final campaignEndTimestamp = data['campaignEndTimestamp'] as Timestamp?;
    final coinMultiplier = (data['coinMultiplier'] as num?)?.toDouble() ?? 1.0;

    final monthlyPrice = data['proMonthlyPriceText'] as String? ?? '₺19.99';
    final yearlyPrice = data['proYearlyPriceText'] as String? ?? '₺199.99';
    final monthlyOldPrice = data['proMonthlyOldPriceText'] as String? ?? '';
    final yearlyOldPrice = data['proYearlyOldPriceText'] as String? ?? '';

    final dealsList = <Widget>[];

    if (monthlyOldPrice.isNotEmpty) {
      dealsList.add(_buildCampaignDealCard(
        context: context,
        icon: Icons.workspace_premium_rounded,
        iconColor: const Color(0xFFFFD700),
        title: tr ? 'Aylık Pro Üyelik' : 'Monthly Pro Subscription',
        oldValue: monthlyOldPrice,
        newValue: monthlyPrice,
        badgeText: tr ? 'İNDİRİM' : 'DISCOUNT',
        badgeColor: const Color(0xFFFFD700),
      ));
    }

    if (yearlyOldPrice.isNotEmpty) {
      if (dealsList.isNotEmpty) dealsList.add(const SizedBox(height: 12));
      dealsList.add(_buildCampaignDealCard(
        context: context,
        icon: Icons.workspace_premium_rounded,
        iconColor: const Color(0xFFFFD700),
        title: tr ? 'Yıllık Pro Üyelik' : 'Yearly Pro Subscription',
        oldValue: yearlyOldPrice,
        newValue: yearlyPrice,
        badgeText: tr ? 'SÜPER FIRSAT' : 'MEGA VALUE',
        badgeColor: const Color(0xFFFFD700),
      ));
    }

    if (coinMultiplier > 1.0) {
      final pack1Coins = ((data['coinsPack1Amount'] as num?)?.toInt() ?? 150);
      final pack2Coins = ((data['coinsPack2Amount'] as num?)?.toInt() ?? 500);
      final pack3Coins = ((data['coinsPack3Amount'] as num?)?.toInt() ?? 1200);

      final pack1Amount = (pack1Coins * coinMultiplier).toInt();
      final pack2Amount = (pack2Coins * coinMultiplier).toInt();
      final pack3Amount = (pack3Coins * coinMultiplier).toInt();

      if (dealsList.isNotEmpty) dealsList.add(const SizedBox(height: 12));
      dealsList.add(Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFCC00),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr ? 'Jeton Paketlerinde Bonus!' : 'Bonus on Coin Packs!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 1),
                  ),
                  child: Text(
                    '${coinMultiplier.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCoinComparisonLine(
              label: tr ? 'Küçük Paket:' : 'Small Pack:',
              oldCoins: pack1Coins,
              newCoins: pack1Amount,
            ),
            const SizedBox(height: 6),
            _buildCoinComparisonLine(
              label: tr ? 'Büyük Paket:' : 'Medium Pack:',
              oldCoins: pack2Coins,
              newCoins: pack2Amount,
            ),
            const SizedBox(height: 6),
            _buildCoinComparisonLine(
              label: tr ? 'Efsanevi Paket:' : 'Mega Pack:',
              oldCoins: pack3Coins,
              newCoins: pack3Amount,
            ),
          ],
        ),
      ));
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: SafeShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          campaignTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD700).withOpacity(0.6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          campaignText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                            fontSize: 14,
                            height: 1.5,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (campaignEndTimestamp != null) ...[
                          GothicCampaignCountdown(
                              endTime: campaignEndTimestamp.toDate()),
                          const SizedBox(height: 20),
                        ],
                        if (dealsList.isNotEmpty) ...[
                          Text(
                            tr ? 'AKTİF KAMPANYALAR' : 'ACTIVE DEALS',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...dealsList,
                          const SizedBox(height: 24),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showProSubscriptionModal(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 5,
                              shadowColor:
                                  Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              tr ? 'FIRSATI YAKALA' : 'SEIZE THE OFFER',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            tr ? 'Karanlığa Dön' : 'Back to Darkness',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCampaignDealCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String oldValue,
    required String newValue,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor, width: 1),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      oldValue,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      newValue,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
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

  Widget _buildCoinComparisonLine({
    required String label,
    required int oldCoins,
    required int newCoins,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
        const Spacer(),
        Text(
          '$oldCoins',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            decoration: TextDecoration.lineThrough,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white54,
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(
          '$newCoins Jeton',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Color? _parseHexColor(String hex) {
    if (hex.isEmpty) return null;
    var path = hex.replaceAll('#', '');
    if (path.length == 6) {
      path = 'FF$path';
    }
    final val = int.tryParse(path, radix: 16);
    if (val != null) {
      return Color(val);
    }
    return null;
  }

  IconData _getAnnouncementIcon(String iconName) {
    return switch (iconName) {
      'info' => Icons.info_outline_rounded,
      'star' => Icons.auto_awesome_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'update' => Icons.new_releases_rounded,
      'warning' => Icons.warning_amber_rounded,
      'announcement' => Icons.campaign_rounded,
      _ => Icons.campaign_rounded,
    };
  }

  void _checkAndShowPopupAnnouncement() async {
    if (_popupAnnouncementChecked) return;
    _popupAnnouncementChecked = true;

    try {
      final data = await notificationRepository.getPopupAnnouncement();
      if (data == null) return;

      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) return;

      final id = data['id'] as String? ?? '';
      if (id.isEmpty) return;

      // Check start and end dates
      final now = DateTime.now();
      final startsAtVal = data['startsAt'];
      final endsAtVal = data['endsAt'];
      DateTime? startsAt;
      DateTime? endsAt;
      if (startsAtVal is Timestamp) startsAt = startsAtVal.toDate();
      if (endsAtVal is Timestamp) endsAt = endsAtVal.toDate();
      if (startsAtVal is String) startsAt = DateTime.tryParse(startsAtVal);
      if (endsAtVal is String) endsAt = DateTime.tryParse(endsAtVal);

      if (startsAt != null && now.isBefore(startsAt)) return;
      if (endsAt != null && now.isAfter(endsAt)) return;

      // Check if already viewed in LocalStorage
      final lastViewedId = await LocalStorage.getString('last_viewed_announcement_id');
      if (lastViewedId == id) return;

      // Show the dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPopupAnnouncementDialog(data);
      });
    } catch (e) {
      print('AppScaffold: Error loading popup announcement: $e');
    }
  }

  void _showPopupAnnouncementDialog(Map<String, dynamic> data) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final id = data['id'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final titleColorStr = data['titleColor'] as String? ?? '';
    final bodyColorStr = data['bodyColor'] as String? ?? '';
    final backgroundColorStr = data['backgroundColor'] as String? ?? '';
    final buttonText = data['buttonText'] as String? ?? (tr ? 'Anladım' : 'Got it');
    final buttonUrl = data['buttonUrl'] as String? ?? '';
    final iconName = data['iconName'] as String? ?? 'announcement';

    final Color? customBgColor = _parseHexColor(backgroundColorStr);
    final Color? customTitleColor = _parseHexColor(titleColorStr);
    final Color? customBodyColor = _parseHexColor(bodyColorStr);

    final dialogBg = customBgColor ?? Theme.of(context).colorScheme.surface;
    final titleColor = customTitleColor ?? Theme.of(context).colorScheme.primary;
    final bodyColor = customBodyColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85);

    showDialog<void>(
      context: context,
      barrierDismissible: false, // Must explicitly close to set viewed ID
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Banner Image if present
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: getWebImage(
                              imageUrl: imageUrl,
                              label: 'Announcement Banner',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          imageUrl.isNotEmpty ? 20 : 36,
                          24,
                          24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon if no banner image
                            if (imageUrl.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  _getAnnouncementIcon(iconName),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: bodyColor,
                                height: 1.5,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Mark as viewed
                                  await LocalStorage.setString('last_viewed_announcement_id', id);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    if (buttonUrl.isNotEmpty) {
                                      if (buttonUrl.startsWith('http://') || buttonUrl.startsWith('https://')) {
                                        launchExternalUrl(buttonUrl);
                                      } else {
                                        _goGuarded(buttonUrl);
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  buttonText,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // X Close Button in top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(imageUrl.isNotEmpty ? 0.4 : 0.0),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: imageUrl.isNotEmpty
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      onPressed: () async {
                        // Mark as viewed
                        await LocalStorage.setString('last_viewed_announcement_id', id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GothicAccessDeniedScreen extends StatelessWidget {
  const GothicAccessDeniedScreen({
    required this.isPermanent,
    this.banUntil,
    super.key,
  });

  final bool isPermanent;
  final DateTime? banUntil;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final title = tr ? 'ERİŞİM ENGELLENDİ' : 'ACCESS DENIED';
    final desc = isPermanent
        ? (tr
            ? 'Hesabınız kuralları ihlal ettiğiniz için süresiz olarak engellenmiştir.'
            : 'Your account has been permanently banned due to violating the rules.')
        : (tr
            ? 'Hesabınız geçici olarak askıya alınmıştır.\nYasak bitiş tarihi: ${_formatDateTime(banUntil!)}'
            : 'Your account has been temporarily suspended.\nSuspension ends: ${_formatDateTime(banUntil!)}');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: GothicPageBackgroundWidget(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.gavel_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.error,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.8),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  OutlinedButton(
                    onPressed: () async {
                      await authService.signOut();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Theme.of(context).colorScheme.primary,
                      elevation: 5,
                    ),
                    child: Text(
                      tr ? 'ÇIKIŞ YAP' : 'SIGN OUT',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year - $hour:$minute';
  }
}

class DailyRewardGiftWidget extends StatefulWidget {
  final User? currentUser;
  final DateTime? lastDailyClaim;

  const DailyRewardGiftWidget({
    super.key,
    required this.currentUser,
    required this.lastDailyClaim,
  });

  @override
  State<DailyRewardGiftWidget> createState() => _DailyRewardGiftWidgetState();
}

class _DailyRewardGiftWidgetState extends State<DailyRewardGiftWidget> {
  bool _isClaiming = false;

  bool get _hasClaimedToday {
    if (widget.currentUser == null) return false;
    final lastClaim = widget.lastDailyClaim;
    if (lastClaim == null) return false;
    final now = DateTime.now();
    return lastClaim.year == now.year &&
        lastClaim.month == now.month &&
        lastClaim.day == now.day;
  }

  Future<void> _handleClaim() async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    if (widget.currentUser == null) {
      final currentLoc = GoRouterState.of(context).uri.toString();
      context.push('/consent?from=${Uri.encodeComponent(currentLoc)}');
      return;
    }

    if (_hasClaimedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr
                ? 'Bugünkü günlük ödülünüzü zaten aldınız.'
                : 'You have already claimed today\'s daily reward.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isClaiming = true;
    });

    try {
      await profileSetupRepository.claimDailyCoins(widget.currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr
                  ? 'Tebrikler! Günlük 5 Jeton kazandınız.'
                  : 'Congratulations! You claimed 5 daily Coins.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr
                  ? 'Ödül alınırken bir hata oluştu: $e'
                  : 'Error claiming reward: $e',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return const SizedBox.shrink();
    }

    final claimed = _hasClaimedToday;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _isClaiming ? null : _handleClaim,
      borderRadius: BorderRadius.circular(22),
      child: _isClaiming
          ? const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : claimed
              ? Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF130B1E).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.4),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFC4B2D9).withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: isDark
                          ? const Color(0xFFC4B2D9).withValues(alpha: 0.35)
                          : Colors.grey.withValues(alpha: 0.45),
                      size: 20,
                    ),
                  ),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF2A1E00)
                        : const Color(0xFFFFFDE7),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 8.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ),
                ),
    );
  }
}
