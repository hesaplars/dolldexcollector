import 'dart:async';
import 'dart:convert';

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
  String _avatarId = '';
  String _avatarFrameColor = '';
  String? _watchedUserId;

  AppNotification? _currentHudNotification;
  bool _showHudBanner = false;
  Timer? _hudTimer;
  final Set<String> _shownNotificationIds = {};
  bool _isFirstNotificationsLoad = true;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  int _unreadNotificationsCount = 0;
  StreamSubscription<List<ChatThread>>? _chatThreadsSubscription;
  bool _hasUnreadDMs = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = authService.authStateChanges.listen((user) {
      _updateProfileSubscription(user);
    });
    _updateProfileSubscription(authService.currentUser);
  }

  Widget _buildNeonTopIcon(IconData icon) {
    return SafeShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFEC008C),
            Color(0xFF00FFCC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
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

  Widget _buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
    // Standard icon helper from theme
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

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = switch (location) {
      '/collection' => 1,
      '/messages' => 2,
      '/social' => 3,
      '/admin' => _isAdmin ? 4 : 0,
      _ => 0,
    };
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final destinations = [
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 0 ? 1.0 : 0.45,
          child: Image.asset(
            'assets/icons/nav_catalog.png',
            width: 28,
            height: 28,
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
          ),
        ),
        label: t(context, 'collection'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _hasUnreadDMs,
          backgroundColor: const Color(0xFFEC008C),
          child: Opacity(
            opacity: selectedIndex == 2 ? 1.0 : 0.45,
            child: Image.asset(
              'assets/icons/nav_messages.png',
              width: 28,
              height: 28,
            ),
          ),
        ),
        label: tr ? 'Mesajlarım' : 'Messages',
      ),
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 3 ? 1.0 : 0.45,
          child: Image.asset(
            'assets/icons/nav_social.png',
            width: 28,
            height: 28,
          ),
        ),
        label: tr ? 'Sosyal' : 'Social',
      ),
      if (_isAdmin)
        NavigationDestination(
          icon: Opacity(
            opacity: selectedIndex == 4 ? 1.0 : 0.45,
            child: Image.asset(
              'assets/icons/nav_admin.png',
              width: 28,
              height: 28,
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
        preferredSize: Size.fromHeight(74 + MediaQuery.of(context).padding.top),
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? DollDexTheme.darkPaper
              : DollDexTheme.paper,
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
                    child: SafeShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFEC008C),
                            Color(0xFF00FFCC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Text(
                        t(context, 'appName').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzel(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (GoRouter.of(context).canPop() || Navigator.of(context).canPop())
                      IconButton(
                        tooltip: AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Geri' : 'Back',
                        icon: _buildNeonTopIcon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          final router = GoRouter.of(context);
                          if (router.canPop()) {
                            router.pop();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    ValueListenableBuilder<AppLanguage>(
                      valueListenable: appLanguageController,
                      builder: (context, language, _) {
                        return IconButton(
                          tooltip: language == AppLanguage.tr ? 'Change language' : 'Dili değiştir',
                          icon: _buildNeonTopIcon(Icons.translate_rounded),
                          onPressed: () {
                            final nextLang = language == AppLanguage.tr ? AppLanguage.en : AppLanguage.tr;
                            appLanguageController.setLanguage(nextLang);
                          },
                        );
                      },
                    ),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: appThemeController,
                      builder: (context, themeMode, _) {
                        return IconButton(
                          tooltip: t(context, 'theme'),
                          onPressed: () {
                            appThemeController.value = themeMode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                          },
                          icon: _buildNeonTopIcon(
                            themeMode == ThemeMode.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                        );
                      },
                    ),

                    Badge(
                      isLabelVisible: _unreadNotificationsCount > 0,
                      label: Text('$_unreadNotificationsCount'),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: IconButton(
                        tooltip: t(context, 'notifications'),
                        onPressed: () => _goGuarded('/notifications', push: true),
                        icon: _buildNeonTopIcon(Icons.notifications_active_rounded),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 4),
                      child: InkWell(
                        onTap: () => _goGuarded('/profile'),
                        borderRadius: BorderRadius.circular(20),
                        child: buildAvatarHelper(
                          authService.currentUser != null ? _avatarId : '',
                          authService.currentUser != null ? _avatarFrameColor : '',
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
                NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    final path = _pathForIndex(index);
                    _goGuarded(path);
                  },
                  destinations: destinations,
                ),
                const GothicAdBannerHorizontal(),
              ],
            )
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                final path = _pathForIndex(index);
                _goGuarded(path);
              },
              destinations: destinations,
            ),
    );

    return PopScope(
      canPop: false,
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
            if (isDesktop)
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
                          description: 'Karanlık ve gizemli gotik bebekler, aksesuarlar ve nadide parçalar burada!',
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
                          description: 'Koleksiyonerler Kulübü\'ne katılın, özel etkinlikleri ve takas fırsatlarını kaçırmayın!',
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
                child: mainScaffold,
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
    _watchedUserId = user?.uid;
    _profileComplete = user == null;
    _isAdmin = false;
    _avatarId = '';
    _avatarFrameColor = '';
    _isFirstNotificationsLoad = true;
    _shownNotificationIds.clear();
    _unreadNotificationsCount = 0;
    _hasUnreadDMs = false;

    if (user == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _profileSubscription = profileSetupRepository.watch(user.uid).listen((status) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileComplete = status.isComplete;
        _isAdmin = status.role == 'admin';
        _avatarId = status.avatarId;
        _avatarFrameColor = status.avatarFrameColor;
      });
    });

    _notificationsSubscription = notificationRepository.watchForUser(user.uid).listen((notifications) {
      if (!mounted) {
        return;
      }
      _onNotificationsUpdated(notifications);
    });

    _chatThreadsSubscription = socialRepository.watchChatThreads(user.uid).listen((threads) {
      _updateUnreadDMsCount(threads, user.uid);
    });

    // Invoke global load function in main.dart
    loadCollectionForCurrentUser();
  }

  void _updateUnreadDMsCount(List<ChatThread> threads, String myUid) async {
    final deleted = await LocalStorage.getStringList('deleted_threads');
    final readTimesRaw = await LocalStorage.getString('last_read_times');
    Map<String, String> readTimes = {};
    if (readTimesRaw != null) {
      try {
        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
      } catch (_) {}
    }

    bool hasUnread = false;
    for (final thread in threads) {
      if (deleted.contains(thread.id)) continue;
      if (thread.lastMessageSenderId == myUid) continue;
      if (thread.lastMessagePreview.isEmpty) continue;

      final lastReadStr = readTimes[thread.id];
      if (lastReadStr == null) {
        hasUnread = true;
        break;
      }
      final lastRead = DateTime.tryParse(lastReadStr);
      if (lastRead == null) {
        hasUnread = true;
        break;
      }
      if (thread.updatedAt != null && thread.updatedAt!.isAfter(lastRead)) {
        hasUnread = true;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _hasUnreadDMs = hasUnread;
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
          color: const Color(0xFF0E0818),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEC008C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC008C).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNeonIcon(context, _notificationTypeIcon(notification.type), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white54),
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
      3 => '/social',
      4 => _isAdmin ? '/admin' : '/',
      _ => '/',
    };
  }

  void _goGuarded(String path, {bool push = false}) {
    final user = authService.currentUser;
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
}
