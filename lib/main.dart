import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'src/admin/catalog_entry_form.dart';
import 'src/monetization/billing_service.dart';
import 'src/auth/auth_service.dart';
import 'src/auth/sign_in_panel.dart';
import 'src/catalog/catalog_models.dart';
import 'src/catalog/catalog_repository.dart';
import 'src/catalog/firestore_catalog_repository.dart';
import 'src/collection/collection_action_sheet.dart';
import 'src/collection/collection_repository.dart';
import 'src/comments/comment_models.dart';
import 'src/comments/comment_repository.dart';
import 'src/core/app_language.dart';
import 'src/core/image_url_validator.dart';
import 'src/core/web_image_helper.dart';
import 'src/core/local_storage_helper.dart';
import 'src/firebase/firebase_bootstrap.dart';
import 'src/moderation/report_models.dart';
import 'src/moderation/report_service.dart';
import 'src/moderation/report_sheet.dart';
import 'src/social/social_models.dart';
import 'src/social/social_repository.dart';
import 'src/users/account_deletion_repository.dart';
import 'src/users/profile_setup_repository.dart';
import 'src/users/user_models.dart';
import 'src/notifications/notification_models.dart';
import 'src/notifications/notification_repository.dart';

import 'src/screens/splash_screen.dart';
import 'src/screens/catalog_screen.dart';
import 'src/screens/catalog_detail_screen.dart';
import 'src/screens/collection_screen.dart';
import 'src/screens/profile_screen.dart';
import 'src/screens/public_profile_screen.dart';
import 'src/screens/settings_screen.dart';
import 'src/screens/legal_screen.dart';
import 'src/screens/account_deletion_screen.dart';
import 'src/screens/social_screen.dart';
import 'src/screens/notifications_screen.dart';
import 'src/screens/announcement_screen.dart';
import 'src/screens/collection_entry_detail_screen.dart';
import 'src/screens/admin_screen.dart';
import 'src/screens/messages_screen.dart';
import 'src/screens/username_profile_loader.dart';
import 'src/screens/user_search_screen.dart';
import 'src/screens/legal_consent_screen.dart';

import 'src/widgets/doll_widgets.dart';
import 'src/widgets/app_scaffold.dart';

final appLanguageController = AppLanguageController();
final appErrorNotifier = ValueNotifier<String?>(null);
final firebaseReadyNotifier = ValueNotifier<bool>(false);
final authService = AuthService();
final notificationRepository = FirestoreNotificationRepository();
final catalogRepository = FirestoreCatalogRepository();
final collectionRepository = FirestoreCollectionRepository();
final commentRepository = FirestoreCommentRepository();
final reportService = ReportService();
final profileSetupRepository = ProfileSetupRepository();
final accountDeletionRepository = AccountDeletionRepository();
final socialRepository = SocialRepository();
final catalogEntriesNotifier = ValueNotifier<List<CatalogEntry>>(
  List<CatalogEntry>.from(fallbackCatalogRepositorySeed),
);
final collectionEntriesNotifier = ValueNotifier<List<CollectionEntry>>(
  <CollectionEntry>[],
);
final reportsNotifier = ValueNotifier<List<UserReport>>(<UserReport>[]);
final commentsNotifier = ValueNotifier<Map<String, List<AppComment>>>(
  <String, List<AppComment>>{},
);
final notificationsNotifier = ValueNotifier<List<String>>(<String>[]);
final appThemeController = ValueNotifier<ThemeMode>(ThemeMode.light);
final ValueNotifier<String> appThemeKeyController = ValueNotifier<String>('goth_dark')..addListener(() {
  LocalStorage.setString('selected_theme', appThemeKeyController.value);
});

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

bool _isCriticalError(Object exception) {
  final str = exception.toString().toLowerCase();
  if (str.contains('http request failed') ||
      str.contains('networkimage') ||
      str.contains('socketexception') ||
      str.contains('httpexception') ||
      str.contains('handshakeexception') ||
      str.contains('failed host lookup') ||
      str.contains('network_error') ||
      str.contains('xmlhttprequest') ||
      str.contains('image resource service') ||
      str.contains('load failed') ||
      str.contains('status code: 0') ||
      str.contains('status code: 404') ||
      str.contains('status code: 500') ||
      str.contains('status code: 502') ||
      str.contains('status code: 503') ||
      str.contains('status code: 504') ||
      str.contains('clientexception') ||
      str.contains('connection failed') ||
      str.contains('connection timed out')) {
    return false;
  }
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedTheme = await LocalStorage.getString('selected_theme');
  if (savedTheme != null && savedTheme.isNotEmpty) {
    appThemeKeyController.value = savedTheme;
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final errStr = 'Render Error: ${details.exception}\n\n${details.stack}';
    // Update notifier asynchronously to avoid setstate during build cycle
    Future.microtask(() {
      appErrorNotifier.value = errStr;
    });
    return Scaffold(
      backgroundColor: const Color(0xFF0F071A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                    SizedBox(width: 8),
                    Text(
                      'RENDER ERROR',
                      style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    details.stack.toString(),
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (!_isCriticalError(details.exception)) {
      return;
    }
    FlutterError.presentError(details);
    final errStr = 'Framework Error: ${details.exception}\n\n${details.stack}';
    Future.microtask(() {
      appErrorNotifier.value = errStr;
    });
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (!_isCriticalError(error)) {
      return true; // Return true to mark the error as handled and suppress console logging
    }
    final errStr = 'Async Error: $error\n\n$stack';
    Future.microtask(() {
      appErrorNotifier.value = errStr;
    });
    return false;
  };

  firebaseReadyNotifier.value = await FirebaseBootstrap.tryInitialize();
  runApp(const DollDexApp());

  firebaseReadyNotifier.addListener(() {
    if (firebaseReadyNotifier.value) {
      _setupCatalogListener();
      _refreshCatalogEntries();
      _loadCollectionForCurrentUser();
      _loadReports();
    }
  });

  if (firebaseReadyNotifier.value) {
    _setupCatalogListener();
    _refreshCatalogEntries();
    _loadCollectionForCurrentUser();
    _loadReports();
  } else {
    _refreshCatalogEntries();
  }
}

class DollDexApp extends StatelessWidget {
  const DollDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: appLanguageController,
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: appLanguageController,
        builder: (context, language, _) {
          return ValueListenableBuilder<String>(
            valueListenable: appThemeKeyController,
            builder: (context, themeKey, _) {
              final activeTheme = DollDexTheme.getThemeData(themeKey);
              return MaterialApp.router(
                title: 'DollDex Collector',
                debugShowCheckedModeBanner: false,
                theme: activeTheme,
                darkTheme: activeTheme,
                themeMode: themeKey == 'goth_light' ? ThemeMode.light : ThemeMode.dark,
                routerConfig: _router,
                builder: (context, child) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: appErrorNotifier,
                    builder: (context, error, _) {
                      if (error != null) {
                        return MaterialApp(
                          debugShowCheckedModeBanner: false,
                          home: Scaffold(
                            backgroundColor: const Color(0xFF0F071A),
                            body: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLanguageScope.languageOf(context) == AppLanguage.tr
                                                ? 'KRİTİK HATA TESPİT EDİLDİ'
                                                : 'CRITICAL ERROR DETECTED',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppLanguageScope.languageOf(context) == AppLanguage.tr
                                            ? 'Lütfen bu ekranın ekran görüntüsünü (screenshot) alıp geliştiriciye gönderin:'
                                            : 'Please take a screenshot of this screen and send it to the developer:',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          error,
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEC008C),
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            appErrorNotifier.value = null;
                                          },
                                          child: Text(
                                            AppLanguageScope.languageOf(context) == AppLanguage.tr
                                                ? 'Hata Kaydını Temizle ve Yeniden Dene'
                                                : 'Clear Error and Retry',
                                          ),
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
                      return child ?? const SizedBox.shrink();
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}












final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/consent',
          builder: (context, state) => const LegalConsentScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'];
            return CatalogScreen(initialQuery: query);
          },
        ),
        GoRoute(
          path: '/catalog/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return '/i/$id';
          },
        ),
        GoRoute(
          path: '/i/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CatalogDetailScreen(
              item: _findCatalogEntry(id),
            );
          },
        ),
        GoRoute(
          path: '/collection',
          builder: (context, state) => const CollectionScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => authService.currentUser == null
              ? const LegalConsentScreen()
              : const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/pro',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/announcement',
          builder: (context, state) {
            final title = state.uri.queryParameters['title'] ?? 'Duyuru';
            final body = state.uri.queryParameters['body'] ?? '';
            return AnnouncementScreen(title: title, body: body);
          },
        ),
        GoRoute(
          path: '/social',
          builder: (context, state) {
            if (authService.currentUser == null) {
              return const LegalConsentScreen();
            }
            final chatUserId = state.uri.queryParameters['chatUserId'];
            return SocialScreen(chatUserId: chatUserId);
          },
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => authService.currentUser == null
              ? const LegalConsentScreen()
              : const MessagesScreen(),
        ),
        GoRoute(
          path: '/users/:id',
          builder: (context, state) {
            return PublicProfileScreen(
              userId: state.pathParameters['id'] ?? '',
            );
          },
        ),
        GoRoute(
          path: '/u/:username',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return UsernameProfileLoader(username: username);
          },
        ),
        GoRoute(
          path: '/user_search',
          builder: (context, state) => authService.currentUser == null
              ? const LegalConsentScreen()
              : const UserSearchScreen(),
        ),
        GoRoute(
          path: '/collection/entry/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return '/c/$id';
          },
        ),
        GoRoute(
          path: '/c/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return UserCollectionEntryDetailScreen(entryId: id);
          },
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => LegalScreen(
            title: t(context, 'privacyPolicy'),
            body: t(context, 'privacyBody'),
          ),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => LegalScreen(
            title: t(context, 'termsOfUse'),
            body: t(context, 'termsBody'),
          ),
        ),
        GoRoute(
          path: '/delete-account',
          builder: (context, state) => const AccountDeletionScreen(),
        ),
      ],
    ),
  ],
);

Widget _buildAvatarHelper(String avatarId, String frameColor, {double size = 40}) {
  String assetPath = '';
  switch (avatarId) {
    case 'avatar-0':
      assetPath = 'assets/avatars/avatar_vampire.png';
      break;
    case 'avatar-1':
      assetPath = 'assets/avatars/avatar_werewolf.png';
      break;
    case 'avatar-2':
      assetPath = 'assets/avatars/avatar_sea.png';
      break;
    case 'avatar-3':
      assetPath = 'assets/avatars/avatar_zombie.png';
      break;
    case 'avatar-4':
      assetPath = 'assets/avatars/avatar_mummy.png';
      break;
    case 'avatar-5':
      assetPath = 'assets/avatars/avatar_phantom.png';
      break;
    case 'avatar-6':
      assetPath = 'assets/avatars/avatar_witch.png';
      break;
    case 'avatar-7':
      assetPath = 'assets/avatars/avatar_gargoyle.png';
      break;
    case 'avatar-8':
      assetPath = 'assets/avatars/avatar_ghost.png';
      break;
    case 'avatar-9':
      assetPath = 'assets/avatars/avatar_spider.png';
      break;
    case 'avatar-10':
      assetPath = 'assets/avatars/avatar_cyber.png';
      break;
    case 'avatar-11':
      assetPath = 'assets/avatars/avatar_skeleton.png';
      break;
    default:
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFEC008C),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC008C).withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
          color: const Color(0xFF160E22),
        ),
        child: Center(
          child: SafeShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Icon(
              Icons.face_3_outlined,
              size: size * 0.6,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  final isGothicFrame = frameColor.startsWith('frame-');
  final parsedColor = !isGothicFrame ? int.tryParse(frameColor, radix: 16) : null;
  final Color? borderColor = parsedColor != null ? Color(parsedColor) : null;

  return Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? const Color(0xFFEC008C).withOpacity(0.15),
            width: borderColor != null ? 3.0 : 1.5,
          ),
          boxShadow: borderColor != null
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderColor != null || isGothicFrame ? 2.0 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEC008C),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC008C).withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                    color: const Color(0xFF160E22),
                  ),
                  child: Center(
                    child: SafeShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Icon(
                        Icons.face_3_outlined,
                        size: size * 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      if (isGothicFrame)
        Positioned.fill(
          child: GothicFrameWidget(frameType: frameColor, size: size),
        ),
    ],
  );
}

































































Future<void> _loadCollectionForCurrentUser() async {
  final userId = authService.currentUser?.uid;
  if (userId == null) {
    return;
  }

  try {
    collectionEntriesNotifier.value =
        await collectionRepository.listForUser(userId);
  } catch (_) {
    return;
  }
}

Future<void> _loadReports() async {
  final reports = await reportService.listReports();
  if (reports.isNotEmpty) {
    reportsNotifier.value = reports;
  }
}

Future<void> loadCollectionForCurrentUser() => _loadCollectionForCurrentUser();
Future<void> loadReports() => _loadReports();



















Widget _buildProfileDirectMessagesCard(BuildContext context, String userId) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Card(
    child: ListTile(
      leading: _buildNeonIcon(context, Icons.forum_rounded, size: 22),
      title: Text(
        tr ? 'Özel Mesajlarım' : 'My Direct Messages',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        tr ? 'Arkadaşlarınızla özel sohbetleri yönetin' : 'Manage direct chats with friends',
        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () => _openDirectMessagesModal(context),
    ),
  );
}





void _showPurchaseDialog({
  required BuildContext context,
  required String userId,
  required String title,
  required int cost,
  required int userCoins,
  required Future<void> Function() onConfirm,
}) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  if (userCoins < cost) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr ? 'Yetersiz Jeton' : 'Insufficient Coins'),
        content: Text(
          tr
              ? 'Bu ürünü satın almak için $cost Jetona ihtiyacınız var. Mevcut jetonunuz: $userCoins.'
              : 'You need $cost Coins to buy this item. Your current balance: $userCoins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr ? 'Kapat' : 'Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showProSubscriptionModal(context);
            },
            child: Text(tr ? 'Jeton Al / Pro Ol' : 'Get Coins / Go Pro'),
          ),
        ],
      ),
    );
  } else {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          tr
              ? 'Bu ürünü $cost Jeton karşılığında açmak istiyor musunuz?\nKalan Jetonunuz: ${userCoins - cost}'
              : 'Do you want to unlock this item for $cost Coins?\nRemaining Coins: ${userCoins - cost}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr ? 'İptal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await onConfirm();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text(tr ? 'Satın Al' : 'Purchase'),
          ),
        ],
      ),
    );
  }
}

void _showBadgeDetailDialog({
  required BuildContext context,
  required String userId,
  required ProfileBadge badge,
  required bool isUnlocked,
  required bool isSelected,
  required ProfileSetupStatus status,
}) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ProfileBadgeWidget(badgeId: badge.id, size: 10),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 18)
            else if (isUnlocked)
              const Icon(Icons.lock_open, color: Colors.green, size: 16)
            else
              const Icon(Icons.lock, color: Colors.grey, size: 16),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              badge.description(context),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (badge.coinsPrice > 0 && !isUnlocked)
              Text(
                tr 
                    ? 'Fiyat: ${badge.coinsPrice} Jeton' 
                    : 'Price: ${badge.coinsPrice} Coins',
                style: const TextStyle(
                  color: Color(0xFFFFCC00),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              )
            else if (!isUnlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  tr 
                      ? 'Bu rozeti kullanabilmek için yukarıdaki şartı sağlamalısın.' 
                      : 'You must meet the requirement above to use this badge.',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr ? 'Kapat' : 'Close'),
          ),
          if (isUnlocked)
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final nextBadge = isSelected ? '' : badge.id;
                await profileSetupRepository.saveSelectedBadge(userId, nextBadge);
              },
              child: Text(
                isSelected 
                    ? (tr ? 'Rozeti Kaldır' : 'Remove Badge') 
                    : (tr ? 'Rozeti Kullan' : 'Equip Badge'),
              ),
            )
          else if (badge.coinsPrice > 0 && !(status.unlockedBadges.contains(badge.id)))
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPurchaseDialog(
                  context: context,
                  userId: userId,
                  title: tr ? 'Rozet Satın Al' : 'Buy Badge',
                  cost: badge.coinsPrice,
                  userCoins: status.coins,
                  onConfirm: () async {
                    await profileSetupRepository.unlockBadge(userId, badge.id, badge.coinsPrice);
                  },
                );
              },
              child: Text(tr ? 'Satın Al' : 'Purchase'),
            ),
        ],
      );
    },
  );
}

void _showAvatarStudioModal(BuildContext context, String userId) {
  final Future<Map<String, dynamic>> badgeDataFuture = () async {
    final commentCountSnap = await FirebaseFirestore.instance
        .collection('comments')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    final commentCount = commentCountSnap.count ?? 0;
    final collection = await collectionRepository.listForUser(userId);
    return {
      'commentCount': commentCount,
      'collection': collection,
    };
  }();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return StreamBuilder<ProfileSetupStatus>(
            stream: profileSetupRepository.watch(userId),
            builder: (context, snapshot) {
              final status = snapshot.data;
              final selectedAvatar = status?.avatarId ?? '';
              final selectedFrame = status?.avatarFrameColor ?? '';
              final selectedCover = status?.coverId ?? 'default';
              final selectedBadge = status?.selectedBadge ?? '';
              final isPro = status?.isPro == true;

              final avatars = [
                'avatar-0', 'avatar-1', 'avatar-2', 'avatar-3',
                'avatar-4', 'avatar-5', 'avatar-6', 'avatar-7',
                'avatar-8', 'avatar-9', 'avatar-10', 'avatar-11',
              ];

              final frames = [
                'frame-0', 'frame-1', 'frame-2', 'frame-3',
                'frame-4', 'frame-5', 'frame-6', 'frame-7',
                'frame-8', 'frame-9', 'frame-10', 'frame-11',
              ];

              final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    tr ? 'Profilini Özelleştir' : 'Customize Your Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: DollDexTheme.teal,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr 
                        ? 'Avatar, çerçeve, rozet ve kapak fotoğraflarını özelleştir.' 
                        : 'Customize your avatar, frame, badge, and cover photos.'
                  ),
                  const SizedBox(height: 16),

                  // Jeton Cüzdanı ve Günlük Ödül (Tıklanabilir Mağaza Entegrasyonu)
                  Builder(
                    builder: (context) {
                      final coins = status?.coins ?? 0;
                      return InkWell(
                        onTap: () {
                          // Mağazayı/Pro Modalını Aç
                          _showProSubscriptionModal(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFCC00), size: 28),
                                  const SizedBox(width: 10),
                                  Text(
                                    tr ? 'Jeton Cüzdanı' : 'Coin Wallet',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tr ? 'Mağaza' : 'Store',
                                          style: const TextStyle(
                                            color: Color(0xFFFFCC00),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.add_circle, color: Color(0xFFFFCC00), size: 10),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$coins',
                                style: const TextStyle(
                                  color: Color(0xFFFFCC00),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  Text(
                    tr ? 'Pro Avatarlar' : 'Pro Avatars',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: avatars.length,
                    itemBuilder: (context, index) {
                      final avatarId = avatars[index];
                      final isSelected = selectedAvatar == avatarId;
                      final isUnlocked = isPro || (status?.unlockedAvatars.contains(avatarId) ?? false);
                      Widget avatarWidget = AvatarOption(
                        avatarId: avatarId,
                        selected: isSelected,
                        frameColor: selectedFrame,
                        onTap: isUnlocked
                            ? () {
                                profileSetupRepository.saveAvatar(
                                  userId: userId,
                                  avatarId: avatarId,
                                  avatarFrameColor: selectedFrame,
                                );
                              }
                            : () {
                                _showPurchaseDialog(
                                  context: context,
                                  userId: userId,
                                  title: tr ? 'Avatar Satın Al' : 'Buy Avatar',
                                  cost: 100,
                                  userCoins: status?.coins ?? 0,
                                  onConfirm: () async {
                                    await profileSetupRepository.unlockAvatar(userId, avatarId, 100);
                                  },
                                );
                              },
                      );

                      if (!isUnlocked) {
                        avatarWidget = Stack(
                          children: [
                            Opacity(
                              opacity: 0.5,
                              child: avatarWidget,
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return avatarWidget;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t(context, 'proFrames'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final frame in frames)
                        Builder(
                          builder: (context) {
                            final isFrameUnlocked = isPro || (status?.unlockedFrames.contains(frame) ?? false);
                            final previewAvatar = selectedAvatar.isNotEmpty ? selectedAvatar : 'avatar-0';
                            return InkWell(
                              onTap: isFrameUnlocked
                                  ? () {
                                      profileSetupRepository.saveAvatar(
                                        userId: userId,
                                        avatarId: selectedAvatar,
                                        avatarFrameColor: frame,
                                      );
                                    }
                                  : () {
                                      _showPurchaseDialog(
                                        context: context,
                                        userId: userId,
                                        title: tr ? 'Çerçeve Satın Al' : 'Buy Frame',
                                        cost: 150,
                                        userCoins: status?.coins ?? 0,
                                        onConfirm: () async {
                                          await profileSetupRepository.unlockFrame(userId, frame, 150);
                                        },
                                      );
                                    },
                              child: Stack(
                                children: [
                                  Opacity(
                                    opacity: isFrameUnlocked ? 1.0 : 0.5,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selectedFrame == frame
                                              ? const Color(0xFFEC008C)
                                              : Colors.transparent,
                                          width: 2.0,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: buildAvatarHelper(
                                        previewAvatar,
                                        frame,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  if (!isFrameUnlocked)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr ? 'Pro Kapak Fotoğrafları' : 'Pro Cover Photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 13,
                      itemBuilder: (context, index) {
                        final coverId = index == 0 ? 'default' : 'cover-${index - 1}';
                        final isSelected = selectedCover == coverId || (coverId == 'default' && selectedCover.isEmpty);
                        final isCoverUnlocked = isPro || coverId == 'default' || (status?.unlockedCovers.contains(coverId) ?? false);
                        return InkWell(
                          onTap: isCoverUnlocked
                              ? () {
                                  profileSetupRepository.saveCover(
                                    userId: userId,
                                    coverId: coverId,
                                  );
                                }
                              : () {
                                  _showPurchaseDialog(
                                    context: context,
                                    userId: userId,
                                    title: tr ? 'Kapak Fotoğrafı Satın Al' : 'Buy Cover Photo',
                                    cost: 200,
                                    userCoins: status?.coins ?? 0,
                                    onConfirm: () async {
                                      await profileSetupRepository.unlockCover(userId, coverId, 200);
                                    },
                                  );
                                },
                          child: Stack(
                            children: [
                              Opacity(
                                opacity: isCoverUnlocked ? 1.0 : 0.5,
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? DollDexTheme.teal
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      children: [
                                        _buildCoverPhotoPreview(coverId),
                                        if (isSelected)
                                          const Center(
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (!isCoverUnlocked)
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.lock,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Profil Rozetleri
                  const SizedBox(height: 24),
                  Text(
                    tr ? 'Profil Rozetleri' : 'Profile Badges',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr 
                        ? 'Rozet detaylarını görmek, kuşanmak veya satın almak için rozete tıkla.' 
                        : 'Click on a badge to view details, equip it, or buy it with coins.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: badgeDataFuture,
                    builder: (context, badgeSnapshot) {
                      if (badgeSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      
                      final data = badgeSnapshot.data ?? {'commentCount': 0, 'collection': <CollectionEntry>[]};
                      final int commentCount = data['commentCount'] as int;
                      final List<CollectionEntry> collection = data['collection'] as List<CollectionEntry>;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: allProfileBadges.length,
                        itemBuilder: (context, index) {
                          final badge = allProfileBadges[index];
                          final isSelected = selectedBadge == badge.id;
                          final isEligible = checkBadgeRequirement(
                            badge, 
                            status ?? const ProfileSetupStatus(
                              userId: '', 
                              displayName: '', 
                              username: '', 
                              birthYear: null, 
                              privacyVersion: '', 
                              termsVersion: '', 
                              role: '', 
                              isPro: false, 
                              avatarId: '', 
                              avatarFrameColor: '', 
                              coverId: ''
                            ), 
                            collection, 
                            commentCount
                          );
                          final isUnlocked = badge.coinsPrice > 0
                              ? (badge.id == 'star'
                                  ? ((status?.unlockedBadges.contains(badge.id) ?? false) || isEligible)
                                  : (status?.unlockedBadges.contains(badge.id) ?? false))
                              : isEligible;
                          
                          return InkWell(
                            onTap: () {
                              _showBadgeDetailDialog(
                                context: context,
                                userId: userId,
                                badge: badge,
                                isUnlocked: isUnlocked,
                                isSelected: isSelected,
                                status: status ?? const ProfileSetupStatus(
                                  userId: '',
                                  displayName: '',
                                  username: '',
                                  birthYear: null,
                                  privacyVersion: '',
                                  termsVersion: '',
                                  role: '',
                                  isPro: false,
                                  avatarId: '',
                                  avatarFrameColor: '',
                                  coverId: ''
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? badge.color.withOpacity(0.15) 
                                    : (isUnlocked ? Colors.grey.shade900.withOpacity(0.5) : Colors.black45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                      ? badge.color 
                                      : (isUnlocked ? Colors.grey.shade800 : Colors.grey.shade900),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ProfileBadgeWidget(badgeId: badge.id, size: 8),
                                  if (isSelected)
                                    const Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Icon(Icons.check_circle, color: Colors.green, size: 10),
                                    )
                                  else if (!isUnlocked)
                                    const Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Icon(Icons.lock, color: Colors.grey, size: 10),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

void _showProSubscriptionModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      final isDark = Theme.of(context).brightness == Brightness.dark;
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
              const SizedBox(height: 24),
              const Divider(color: DollDexTheme.line, height: 1),
              const SizedBox(height: 20),
              Text(
                tr ? 'Jeton Satın Al' : 'Buy Coins',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: DollDexTheme.teal,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                tr
                    ? 'Jetonlar ile ek takas, yorum yapma veya profilinizi öne çıkarma limitlerini arttırabilirsiniz.'
                    : 'Use coins to increase limits for trades, comments or profile showcases.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              _buildCoinPackItem(
                context: context,
                amount: 150,
                price: '₺19.99',
                description: tr ? 'Başlangıç gotik cüzdan paketi' : 'Starter gothic wallet pack',
                isPopular: false,
                onTap: () => _handleBuyCoinPack(context, 150, '₺19.99'),
              ),
              _buildCoinPackItem(
                context: context,
                amount: 500,
                price: '₺49.99',
                description: tr ? 'Koleksiyoncuların en çok tercih ettiği paket' : 'Most preferred pack by collectors',
                isPopular: true,
                onTap: () => _handleBuyCoinPack(context, 500, '₺49.99'),
              ),
              _buildCoinPackItem(
                context: context,
                amount: 1200,
                price: '₺99.99',
                description: tr ? 'Büyük gotik bebek takas ve vitrin paketi' : 'Large trade and showcase pack',
                isPopular: false,
                onTap: () => _handleBuyCoinPack(context, 1200, '₺99.99'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildCoinPackItem({
  required BuildContext context,
  required int amount,
  required String price,
  required String description,
  required bool isPopular,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isPopular ? const Color(0xFFFFCC00) : (isDark ? const Color(0xFFEC008C).withOpacity(0.3) : Colors.black12),
        width: isPopular ? 1.8 : 1.0,
      ),
      color: isPopular 
          ? (isDark ? const Color(0xFF231707) : const Color(0xFFFFFDF5))
          : (isDark ? const Color(0xFF130820) : Colors.white),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCC00).withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFCC00), size: 24),
      ),
      title: Row(
        children: [
          Text(
            '$amount Jeton / Coins',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          if (isPopular) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'POPÜLER' : 'POPULAR',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Outfit',
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      trailing: Text(
        price,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
        ),
      ),
    ),
  );
}

Future<void> _handleBuyCoinPack(BuildContext context, int amount, String price) async {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final user = authService.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr ? 'Öncelikle giriş yapmalısınız!' : 'Please sign in first!')),
    );
    return;
  }
  
  final confirmed = await _showGothicConfirmDialog(
    context,
    title: tr ? 'Jeton Paketini Onayla' : 'Confirm Coin Package',
    content: tr 
        ? '$amount jeton paketini $price karşılığında satın almak istediğinize emin misiniz?'
        : 'Are you sure you want to purchase $amount coins for $price?',
    confirmText: tr ? 'Satın Al' : 'Purchase',
  );
  
  if (confirmed == true) {
    try {
      await profileSetupRepository.buyCoinPackage(user.uid, amount);
      if (context.mounted) {
        Navigator.of(context).pop(); // close the subscription sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr ? 'Tebrikler! $amount Jeton hesabınıza eklendi.' : 'Congratulations! $amount Coins added to your account.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr ? 'İşlem başarısız: $e' : 'Transaction failed: $e')),
        );
      }
    }
  }
}





















void _showPublicProfileActionsMenu(BuildContext context, String targetUserId) {
  final currentUserId = authService.currentUser?.uid;
  if (currentUserId == null) return;

  showModalBottomSheet(
    context: context,
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      return SafeArea(
        child: StreamBuilder<bool>(
          stream: socialRepository.watchIsFriend(currentUserId, targetUserId),
          builder: (context, friendSnap) {
            final isFriend = friendSnap.data ?? false;
            return StreamBuilder<bool>(
              stream: socialRepository.watchHasPendingRequest(currentUserId, targetUserId),
              builder: (context, pendingSnap) {
                final hasPendingOut = pendingSnap.data ?? false;
                return StreamBuilder<bool>(
                  stream: socialRepository.watchHasPendingRequest(targetUserId, currentUserId),
                  builder: (context, pendingInSnap) {
                    final hasPendingIn = pendingInSnap.data ?? false;
                    return StreamBuilder<List<String>>(
                      stream: socialRepository.watchBlockedUsers(currentUserId),
                      builder: (context, blockedSnap) {
                        final isBlocked = (blockedSnap.data ?? []).contains(targetUserId);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFriend)
                              ListTile(
                                leading: _buildNeonIcon(context, Icons.forum_rounded, size: 22),
                                title: Text(tr ? 'Mesaj Gönder' : 'Send Message'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _openDirectChatWithUser(context, targetUserId);
                                },
                              )
                            else if (hasPendingOut)
                              ListTile(
                                leading: _buildNeonIcon(context, Icons.hourglass_empty_rounded, size: 22),
                                title: Text(tr ? 'Arkadaşlık İsteği Gönderildi' : 'Friend Request Sent'),
                                subtitle: Text(tr ? 'Yanıt bekleniyor...' : 'Waiting for response...'),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final confirmed = await _showGothicConfirmDialog(
                                      context,
                                      title: tr ? 'İsteği İptal Et' : 'Cancel Request',
                                      content: tr
                                          ? 'Arkadaşlık isteğini iptal etmek istediğinize emin misiniz?'
                                          : 'Are you sure you want to cancel the friend request?',
                                    );
                                    if (!confirmed) return;
                                    await socialRepository.removeFriend(
                                      userA: currentUserId,
                                      userB: targetUserId,
                                    );
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                  child: Text(t(context, 'cancel')),
                                ),
                              )
                            else if (hasPendingIn)
                              ListTile(
                                leading: _buildNeonIcon(context, Icons.person_add_alt_1_rounded, size: 22),
                                title: Text(tr ? 'Arkadaşlık İsteğini Kabul Et' : 'Accept Friend Request'),
                                onTap: () async {
                                  final confirmed = await _showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'İsteği Kabul Et' : 'Accept Request',
                                    content: tr
                                        ? 'Arkadaşlık isteğini kabul etmek istediğinize emin misiniz?'
                                        : 'Are you sure you want to accept the friend request?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.respondToFriendRequest(
                                    fromUserId: targetUserId,
                                    toUserId: currentUserId,
                                    accept: true,
                                  );
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                              )
                            else
                              ListTile(
                                leading: _buildNeonIcon(context, Icons.person_add_alt_1_outlined, size: 22),
                                title: Text(t(context, 'sendFriendRequest')),
                                onTap: () async {
                                  final confirmed = await _showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'Arkadaş Ekle' : 'Add Friend',
                                    content: tr
                                        ? 'Bu kullanıcıya arkadaşlık isteği göndermek istiyor musunuz?'
                                        : 'Do you want to send a friend request to this user?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.sendFriendRequest(
                                    fromUserId: currentUserId,
                                    toUserId: targetUserId,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(t(context, 'friendRequestSent'))),
                                    );
                                  }
                                },
                              ),
                            if (isFriend)
                              ListTile(
                                leading: _buildNeonIcon(context, Icons.person_remove_outlined, size: 22),
                                title: Text(tr ? 'Arkadaşlıktan Çıkar' : 'Unfriend'),
                                onTap: () async {
                                  final confirmed = await _showGothicConfirmDialog(
                                    context,
                                    title: tr ? 'Arkadaşlıktan Çıkar' : 'Unfriend',
                                    content: tr
                                        ? 'Bu kullanıcıyı arkadaşlarınızdan çıkarmak istediğinize emin misiniz?'
                                        : 'Are you sure you want to remove this user from friends?',
                                  );
                                  if (!confirmed) return;
                                  await socialRepository.removeFriend(
                                    userA: currentUserId,
                                    userB: targetUserId,
                                  );
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                              ),
                            ListTile(
                              leading: _buildNeonIcon(
                                context,
                                isBlocked ? Icons.block_flipped : Icons.block,
                                size: 22,
                              ),
                              title: Text(
                                isBlocked
                                    ? (tr ? 'Engeli Kaldır' : 'Unblock User')
                                    : (tr ? 'Engelle' : 'Block User'),
                              ),
                              onTap: () async {
                                final confirmed = await _showGothicConfirmDialog(
                                  context,
                                  title: isBlocked
                                      ? (tr ? 'Engeli Kaldır' : 'Unblock User')
                                      : (tr ? 'Kullanıcıyı Engelle' : 'Block User'),
                                  content: isBlocked
                                      ? (tr ? 'Bu kullanıcının engelini kaldırmak istediğinize emin misiniz?' : 'Are you sure you want to unblock this user?')
                                      : (tr ? 'Bu kullanıcıyı engellemek istediğinize emin misiniz?' : 'Are you sure you want to block this user?'),
                                );
                                if (!confirmed) return;

                                if (isBlocked) {
                                  await socialRepository.unblockUser(
                                    blockerId: currentUserId,
                                    blockedId: targetUserId,
                                  );
                                } else {
                                  await socialRepository.blockUser(
                                    blockerId: currentUserId,
                                    blockedId: targetUserId,
                                  );
                                }
                                if (context.mounted) Navigator.of(context).pop();
                              },
                            ),
                            ListTile(
                              leading: _buildNeonFlagIcon(context, size: 22),
                              title: Text(t(context, 'report')),
                              onTap: () {
                                Navigator.of(context).pop();
                                _showReportSheet(
                                  context,
                                  ReportTargetType.profile,
                                  targetUserId,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      );
    },
  );
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
  String formattedTime = _formatMessageTime(report.createdAt);

  return ResolvedReportDetails(
    reporterName: reporterName,
    reportedName: reportedName,
    contentText: contentText,
    formattedTime: formattedTime,
  );
}



// _buildCompactAdminButton removed since PopUpMenuButton is now used.



Future<void> _saveCatalogDraft(
  BuildContext context,
  CatalogEntryDraft draft,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final entry = CatalogEntry(
    id: draft.id ??
        _slugify('${draft.type.name}-${draft.name}-${draft.year ?? 'draft'}'),
    name: draft.name,
    type: draft.type,
    subtitle: draft.subtitle,
    imageUrls: draft.imageUrl
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList(),
    year: draft.year,
    tags: draft.tags,
    description: draft.description,
    parentId: draft.parentId,
    series: draft.series,
  );

  try {
    await catalogRepository.saveDraft(entry);
    await _refreshCatalogEntries();
    _addAppNotification('${entry.name}: ${t(context, 'catalogEntrySaved')}');
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Monster cataloged successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Kayıt başarısız: $error')),
    );
  }
}

Future<void> _refreshCatalogEntries() async {
  catalogEntriesNotifier.value = await catalogRepository.search();
}

void _setupCatalogListener() {
  if (!firebaseReadyNotifier.value) {
    return;
  }
  FirebaseFirestore.instance.collection('items').snapshots().listen((snapshot) {
    final firestoreItems = <CatalogEntry>[];
    for (final doc in snapshot.docs) {
      try {
        firestoreItems.add(CatalogEntry.fromMap(doc.id, doc.data()));
      } catch (e) {
        print('Error parsing firestore catalog item ${doc.id}: $e');
      }
    }

    final Map<String, CatalogEntry> mergedMap = {};
    for (final item in fallbackCatalogRepositorySeed) {
      mergedMap[item.id] = item;
    }
    for (final item in firestoreItems) {
      mergedMap[item.id] = item;
    }

    final sortedList = mergedMap.values.toList();
    sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    catalogEntriesNotifier.value = sortedList;
  }, onError: (error) {
    print('Firestore catalog listener error: $error');
  });
}

CatalogEntry _findCatalogEntry(String id) {
  return catalogEntriesNotifier.value.firstWhere(
    (item) => item.id == id,
    orElse: () => fallbackCatalogRepositorySeed.firstWhere(
      (item) => item.id == id,
      orElse: () => const CatalogEntry(
        id: 'missing',
        name: 'Catalog entry not found',
        type: CatalogItemType.doll,
        subtitle: 'This item may have been removed or is not available yet.',
        imageUrls: [],
        tags: ['missing'],
      ),
    ),
  );
}

List<CatalogEntry> _filterCatalogEntries(
  List<CatalogEntry> entries,
  String query,
  CatalogItemType? type,
) {
  final normalizedQuery = query.trim().toLowerCase();
  return entries.where((entry) {
    final matchesType = type == null || entry.type == type;
    if (!matchesType) {
      return false;
    }

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return entry.name.toLowerCase().contains(normalizedQuery) ||
        entry.subtitle.toLowerCase().contains(normalizedQuery) ||
        entry.description.toLowerCase().contains(normalizedQuery) ||
        (entry.series?.toLowerCase().contains(normalizedQuery) ?? false) ||
        entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
  }).toList(growable: false);
}

String _slugify(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  final slug = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  if (slug.isEmpty) {
    return 'entry-${DateTime.now().millisecondsSinceEpoch}';
  }

  return slug;
}

void _showReportSheet(
  BuildContext context,
  ReportTargetType targetType,
  String targetId,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return ReportSheet(
        targetType: targetType,
        targetId: targetId,
        onSubmit: (draft) {
          final reporterId = authService.currentUser?.uid ?? 'local-user';
          final report = UserReport(
            id: 'report-${DateTime.now().millisecondsSinceEpoch}',
            reporterId: reporterId,
            targetType: draft.targetType,
            targetId: draft.targetId,
            reason: draft.reason,
            status: ReportStatus.open,
            details: draft.details,
          );
          reportsNotifier.value = [report, ...reportsNotifier.value];
          reportService.createReport(report).catchError((_) => '');
          _addAppNotification(t(context, 'reportSaved'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'reportSaved'))),
          );
        },
      );
    },
  );
}

void _deleteReport(String id) {
  reportsNotifier.value = reportsNotifier.value
      .where((report) => report.id != id)
      .toList(growable: false);
  reportService.deleteReport(id).catchError((_) {});
}

void _updateReportStatus(String id, ReportStatus status) {
  final reportIndex = reportsNotifier.value.indexWhere((r) => r.id == id);
  if (reportIndex == -1) return;
  final report = reportsNotifier.value[reportIndex];

  reportsNotifier.value = reportsNotifier.value.map((r) {
    if (r.id != id) {
      return r;
    }

    return UserReport(
      id: r.id,
      reporterId: r.reporterId,
      targetType: r.targetType,
      targetId: r.targetId,
      reason: r.reason,
      status: status,
      createdAt: r.createdAt,
      details: r.details,
    );
  }).toList(growable: false);
  reportService.updateStatus(id, status).then((_) {
    _addModerationNotification(report.reporterId, report, status);
  }).catchError((_) {});
}

void _deleteCatalogEntry(String id) {
  catalogEntriesNotifier.value = catalogEntriesNotifier.value
      .where((entry) => entry.id != id)
      .toList(growable: false);
  collectionEntriesNotifier.value = collectionEntriesNotifier.value
      .where((entry) => entry.itemId != id)
      .toList(growable: false);

  final comments = {...commentsNotifier.value};
  comments.remove(id);
  commentsNotifier.value = comments;

  catalogRepository.delete(id).catchError((_) {});
}

Future<void> _deleteReportedContent(BuildContext context, UserReport report) async {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final confirmed = await _showGothicConfirmDialog(
    context,
    title: tr ? 'İçeriği İmha Et' : 'Destroy Content',
    content: tr
        ? 'Bu işlem bu içeriği veritabanından kalıcı olarak silecektir. Emin misiniz?'
        : 'This action will permanently delete this content from the database. Are you sure?',
    confirmText: tr ? 'İmha Et' : 'Destroy',
  );

  if (confirmed != true) return;

  final messenger = ScaffoldMessenger.of(context);
  if (report.targetType == ReportTargetType.comment) {
    commentRepository.delete(report.targetId).then((_) {
      final newMap = <String, List<AppComment>>{};
      commentsNotifier.value.forEach((itemId, list) {
        newMap[itemId] = list.where((c) => c.id != report.targetId).toList();
      });
      commentsNotifier.value = newMap;
      _updateReportStatus(report.id, ReportStatus.resolved);
      messenger.showSnackBar(
        SnackBar(content: Text(tr ? 'Yorum veritabanından imha edildi.' : 'Comment destroyed from database.')),
      );
    }).catchError((err) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr ? 'Hata: Yorum silinemedi.' : 'Error: Failed to delete comment.')),
      );
    });
  } else if (report.targetType == ReportTargetType.catalogEntry) {
    catalogRepository.delete(report.targetId).then((_) {
      _deleteCatalogEntry(report.targetId);
      _updateReportStatus(report.id, ReportStatus.resolved);
      messenger.showSnackBar(
        SnackBar(content: Text(tr ? 'Katalog öğesi veritabanından imha edildi.' : 'Catalog item destroyed from database.')),
      );
    }).catchError((err) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr ? 'Hata: Katalog öğesi silinemedi.' : 'Error: Failed to delete catalog item.')),
      );
    });
  }
}





void _addAppNotification(String text) {
  notificationsNotifier.value = [
    text,
    ...notificationsNotifier.value.take(24),
  ];
}

bool _isTemplateEntry(CatalogEntry entry) {
  return entry.id.startsWith('template-');
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

void _showCollectionSheet(BuildContext context, CatalogEntry item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return CollectionActionSheet(
        item: item,
        onSave: (draft) async {
          final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
          final confirmed = await _showGothicConfirmDialog(
            context,
            title: tr ? 'Koleksiyonu Güncelle' : 'Update Collection',
            content: tr
                ? '${_entryName(context, item)} öğesini koleksiyonunuza kaydetmek istiyor musunuz?'
                : 'Do you want to save ${_entryName(context, item)} to your collection?',
          );
          if (!confirmed) return false;

          final userId = authService.currentUser?.uid ?? 'local-user';
          final entry = CollectionEntry(
            id: '$userId-${draft.itemId}',
            userId: userId,
            itemId: draft.itemId,
            status: draft.status,
            condition: draft.condition,
            quantity: draft.quantity,
            notes: draft.notes,
            isPublic: draft.isPublic,
          );
          collectionEntriesNotifier.value = [
            entry,
            ...collectionEntriesNotifier.value.where(
              (existing) => existing.itemId != entry.itemId,
            ),
          ];
          collectionRepository.save(entry).catchError((Object error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Koleksiyon kaydı başarısız: $error')),
              );
            }
          });
          _addAppNotification(
            '${_entryName(context, item)} ${t(context, 'collectionUpdated')}',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${_entryName(context, item)} ${t(context, 'markedAs')} '
                  '${_collectionStatusLabel(context, draft.status)}.',
                ),
              ),
            );
          }
          return true;
        },
      );
    },
  );
}

String _entryName(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterName'),
    'template-doll' => t(context, 'templateDollName'),
    'template-pet' => t(context, 'templatePetName'),
    'template-accessory' => t(context, 'templateAccessoryName'),
    _ => item.name,
  };
}

String _entrySubtitle(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterSubtitle'),
    'template-doll' => t(context, 'templateDollSubtitle'),
    'template-pet' => t(context, 'templatePetSubtitle'),
    'template-accessory' => t(context, 'templateAccessorySubtitle'),
    _ => item.subtitle,
  };
}

String _entryDescription(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterDescription'),
    'template-doll' => t(context, 'templateDollDescription'),
    'template-pet' => t(context, 'templatePetDescription'),
    'template-accessory' => t(context, 'templateAccessoryDescription'),
    _ => item.description,
  };
}

String _catalogTypeLabel(BuildContext context, CatalogItemType type) {
  return switch (type) {
    CatalogItemType.character => t(context, 'typeCharacter'),
    CatalogItemType.doll => t(context, 'typeDoll'),
    CatalogItemType.set => t(context, 'typeSet'),
    CatalogItemType.pet => t(context, 'typePet'),
    CatalogItemType.accessory => t(context, 'typeAccessory'),
  };
}

String _collectionStatusLabel(BuildContext context, CollectionStatus status) {
  return switch (status) {
    CollectionStatus.owned => t(context, 'statusOwned'),
    CollectionStatus.wanted => t(context, 'statusWanted'),
    CollectionStatus.trade => t(context, 'statusTrade'),
    CollectionStatus.selling => t(context, 'statusSelling'),
  };
}

String _conditionLabel(BuildContext context, CollectionCondition condition) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (condition) {
    CollectionCondition.boxed => tr ? 'Kutulu' : 'Boxed',
    CollectionCondition.unboxed => tr ? 'Kutusuz' : 'Unboxed',
    CollectionCondition.complete => tr ? 'Tam' : 'Complete',
    CollectionCondition.incomplete => tr ? 'Eksik' : 'Incomplete',
    CollectionCondition.damaged => tr ? 'Hasarlı' : 'Damaged',
  };
}

Future<bool> _showGothicConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final finalConfirmText = confirmText ?? (tr ? 'Onayla' : 'Confirm');
  final finalCancelText = cancelText ?? (tr ? 'Vazgeç' : 'Cancel');

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: GothicIvyContainer(
          borderRadius: 20,
          color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF6FC),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFFEC008C),
                  shadows: isDark ? [
                    const Shadow(
                      color: Color(0xFFEC008C),
                      blurRadius: 10,
                    ),
                  ] : [],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEC008C), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        finalCancelText,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFFEC008C),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cinzel',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          finalConfirmText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cinzel',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

String _reportReasonLabel(BuildContext context, ReportReason reason) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (reason) {
    ReportReason.spam => 'Spam',
    ReportReason.harassment => tr ? 'Taciz' : 'Harassment',
    ReportReason.unsafeLink => tr ? 'Güvenli olmayan link' : 'Unsafe link',
    ReportReason.copyright => tr ? 'Telif hakkı' : 'Copyright',
    ReportReason.wrongInformation => tr ? 'Yanlış bilgi' : 'Wrong information',
    ReportReason.inappropriateImage =>
      tr ? 'Uygunsuz görsel' : 'Inappropriate image',
    ReportReason.other => tr ? 'Diğer' : 'Other',
  };
}

String _reportStatusLabel(BuildContext context, ReportStatus status) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (status) {
    ReportStatus.open => tr ? 'Açık' : 'Open',
    ReportStatus.reviewing => tr ? 'İncelemede' : 'Reviewing',
    ReportStatus.resolved => tr ? 'Çözüldü' : 'Resolved',
    ReportStatus.dismissed => tr ? 'Reddedildi' : 'Dismissed',
  };
}

// _reportSubtitle removed as it was replaced by dynamic FutureBuilder resolving

String _formatMessageTime(DateTime? value) {
  if (value == null) {
    return '';
  }

  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

void _openReportTarget(BuildContext context, UserReport report) {
  final router = GoRouter.of(context);
  if (report.targetType == ReportTargetType.catalogEntry) {
    router.go('/i/${report.targetId}');
  } else if (report.targetType == ReportTargetType.profile || report.targetType == ReportTargetType.user) {
    router.go('/users/${report.targetId}');
  } else if (report.targetType == ReportTargetType.collectionEntry) {
    router.go('/c/${report.targetId}');
  } else if (report.targetType == ReportTargetType.comment) {
    FirebaseFirestore.instance.collection('comments').doc(report.targetId).get().then((doc) {
      if (doc.exists) {
        final targetType = doc.data()?['targetType'] as String?;
        final targetId = doc.data()?['targetId'] as String?;
        if (targetType == 'catalogEntry') {
          router.go('/i/$targetId');
        } else if (targetType == 'collectionEntry') {
          router.go('/c/$targetId');
        } else if (targetType == 'profile') {
          router.go('/users/$targetId');
        } else {
          router.go('/social');
        }
      } else {
        router.push('/social');
      }
    }).catchError((_) {
      router.push('/social');
    });
  } else {
    router.push('/social');
  }
}

Future<String> _resolveReportTargetText(UserReport report) async {
  try {
    switch (report.targetType) {
      case ReportTargetType.user:
      case ReportTargetType.profile:
        final doc = await FirebaseFirestore.instance.collection('users').doc(report.targetId).get();
        if (doc.exists) {
          final username = doc.data()?['username'] as String?;
          if (username != null && username.isNotEmpty) {
            return '@$username';
          }
        }
        return 'ID: ${report.targetId}';
      case ReportTargetType.comment:
        final doc = await FirebaseFirestore.instance.collection('comments').doc(report.targetId).get();
        if (doc.exists) {
          final text = doc.data()?['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return text;
          }
        }
        return 'ID: ${report.targetId}';
      case ReportTargetType.catalogEntry:
        final doc = await FirebaseFirestore.instance.collection('items').doc(report.targetId).get();
        if (doc.exists) {
          final name = doc.data()?['name'] as String?;
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
        return 'ID: ${report.targetId}';
      default:
        return 'ID: ${report.targetId}';
    }
  } catch (_) {
    return 'ID: ${report.targetId}';
  }
}

Future<void> _addModerationNotification(String userId, UserReport report, ReportStatus status) async {
  try {
    final db = FirebaseFirestore.instance;
    final statusTextTr = switch (status) {
      ReportStatus.open => 'Açık',
      ReportStatus.reviewing => 'İnceleniyor',
      ReportStatus.resolved => 'Çözüldü',
      ReportStatus.dismissed => 'Reddedildi',
    };
    final statusTextEn = switch (status) {
      ReportStatus.open => 'Open',
      ReportStatus.reviewing => 'Reviewing',
      ReportStatus.resolved => 'Resolved',
      ReportStatus.dismissed => 'Dismissed',
    };
    final targetLabelTr = switch (report.targetType) {
      ReportTargetType.user => 'kullanıcı',
      ReportTargetType.profile => 'profil',
      ReportTargetType.comment => 'yorum',
      ReportTargetType.image => 'görsel',
      ReportTargetType.catalogEntry => 'katalog',
      ReportTargetType.collectionEntry => 'koleksiyon',
    };
    final targetLabelEn = switch (report.targetType) {
      ReportTargetType.user => 'user',
      ReportTargetType.profile => 'profile',
      ReportTargetType.comment => 'comment',
      ReportTargetType.image => 'image',
      ReportTargetType.catalogEntry => 'catalog entry',
      ReportTargetType.collectionEntry => 'collection entry',
    };

    await db.collection('notifications').add({
      'userId': userId,
      'type': 'moderation',
      'title': 'Moderasyon Kararı / Moderation Update',
      'body': 'Raporladığın $targetLabelTr içeriği hakkında karar verildi: $statusTextTr / The reported $targetLabelEn content was updated to: $statusTextEn',
      'isRead': false,
      'deepLink': '/profile',
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}













Widget _buildFilterChip({
  required BuildContext context,
  required bool isSelected,
  required String label,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? const Color(0xFFEC008C).withOpacity(0.15)
            : (isDark ? const Color(0xFF171026) : Colors.white),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFEC008C)
              : (isDark ? const Color(0xFF2C1F45) : const Color(0xFFEC008C).withOpacity(0.25)),
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFEC008C).withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            : (isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFFEC008C))
              : (isDark ? Colors.white70 : const Color(0xFF6B5885)),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ),
  );
}

Widget _buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
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
      size: size,
    ),
  );
}

Widget _buildGothicNeonIconButton({
  required BuildContext context,
  required IconData icon,
  VoidCallback? onPressed,
  double size = 20,
  EdgeInsets padding = const EdgeInsets.all(8),
  Color? activeColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final finalColor = activeColor ?? const Color(0xFFEC008C);

  final child = Container(
    padding: padding,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF2FF),
      border: Border.all(
        color: finalColor.withOpacity(0.8),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: finalColor.withOpacity(0.15),
          blurRadius: 4,
          spreadRadius: 0.5,
        ),
      ],
    ),
    child: _buildNeonIcon(context, icon, size: size),
  );

  if (onPressed != null) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(size + 20),
      child: child,
    );
  }

  return child;
}

Widget _buildNeonFlagIcon(BuildContext context, {double size = 24}) {
  return _buildNeonIcon(context, Icons.flag_outlined, size: size);
}

void _showChangeUsernameDialog(BuildContext context, String userId) {
  showDialog(
    context: context,
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      final controller = TextEditingController();
      bool isSaving = false;
      String? errorText;

      return StreamBuilder<ProfileSetupStatus>(
        stream: profileSetupRepository.watch(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snapshot.data!;
          if (controller.text.isEmpty && status.username.isNotEmpty) {
            controller.text = status.username;
          }

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(tr ? 'Kullanıcı Adı Değiştir' : 'Change Username'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr
                          ? 'Kullanıcı adını 6 ayda bir kez değiştirebilirsin.'
                          : 'You can change your username once every 6 months.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 15,
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: InputDecoration(
                        labelText: t(context, 'username'),
                        prefixText: '@',
                        helperText: t(context, 'usernameRules'),
                        errorText: errorText,
                        labelStyle: const TextStyle(fontFamily: 'Cinzel'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2C1F45)
                                : const Color(0xFFE9D8FA),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFEC008C),
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
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(t(context, 'cancel')),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final input = controller.text.trim();
                            final normalized = ProfileSetupRepository.normalizeUsername(input);
                            if (!ProfileSetupRepository.isValidUsername(normalized)) {
                              setState(() {
                                errorText = t(context, 'usernameInvalid');
                              });
                              return;
                            }
                            setState(() {
                              isSaving = true;
                              errorText = null;
                            });
                            try {
                              await profileSetupRepository.saveRequiredProfile(
                                userId: userId,
                                username: normalized,
                                birthYear: status.birthYear ?? 2000,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t(context, 'profileSaved'))),
                                );
                              }
                            } on UsernameTakenException {
                              setState(() {
                                isSaving = false;
                                errorText = t(context, 'usernameTaken');
                              });
                            } on UsernameChangeLockedException {
                              setState(() {
                                isSaving = false;
                                errorText = t(context, 'usernameChangeLocked');
                              });
                            } catch (e) {
                              setState(() {
                                isSaving = false;
                                errorText = '${t(context, 'profileSaveFailed')} $e';
                              });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr ? 'Kaydet' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}





Widget _buildCollectionCategoryTab(BuildContext context, List<CollectionEntry> categoryEntries) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  if (categoryEntries.isEmpty) {
    return Center(
      child: Text(
        tr ? 'Bu kategoride öge yok' : 'No items in this category',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }

  return GridView.builder(
    padding: const EdgeInsets.all(4),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 0.66,
    ),
    itemCount: categoryEntries.length,
    itemBuilder: (context, index) {
      final entry = categoryEntries[index];
      final item = _findCatalogEntry(entry.itemId);
      final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
      return Card(
        color: isPng ? Colors.transparent : null,
        elevation: isPng ? 0 : 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/c/${entry.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: DollImage(
                    imageUrl: item.primaryImageUrl,
                    label: _entryName(context, item),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _entryName(context, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      '${tr ? 'Adet' : 'Qty'}: ${entry.quantity}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
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





Widget _buildCoverPhoto(BuildContext context, String? coverId, {required bool isPro}) {
  final showDefault = !isPro || coverId == null || coverId.isEmpty || coverId == 'default';
  
  if (showDefault) {
    return Container(
      height: 125,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/covers/cover_default.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF130820), Color(0xFF2E0C4C), Color(0xFFEC008C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          Center(
            child: SafeShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [Color(0xFF00FFCC), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds);
              },
              child: Text(
                'DOLLDEX COLLECTOR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: Colors.white,
                  fontFamily: 'Cinzel',
                  shadows: [
                    Shadow(
                      color: const Color(0xFFEC008C).withValues(alpha: 0.8),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final String assetName = coverId.replaceAll('-', '_');
  return Container(
    height: 125,
    width: double.infinity,
    child: Image.asset(
      'assets/covers/$assetName.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF1C0D2B),
        );
      },
    ),
  );
}

Widget _buildCoverPhotoPreview(String coverId) {
  if (coverId == 'default') {
    return Container(
      width: double.infinity,
      height: 60,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/covers/cover_default.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF130820), Color(0xFF2E0C4C), Color(0xFFEC008C)],
                  ),
                ),
              );
            },
          ),
          const Center(
            child: Text(
              'DOLLDEX',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
                fontFamily: 'Cinzel',
              ),
            ),
          ),
        ],
      ),
    );
  }

  final String assetName = coverId.replaceAll('-', '_');
  return Container(
    width: double.infinity,
    height: 60,
    child: Image.asset(
      'assets/covers/$assetName.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF1C0D2B),
        );
      },
    ),
  );
}

Widget _buildStatItem(BuildContext context, {required String label, required String value}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1C0D2B),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          fontFamily: 'Cinzel',
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF1C0D2B).withOpacity(0.6),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'Cinzel',
        ),
      ),
    ],
  );
}

void _showConnectionsModal(BuildContext parentContext, String userId) {
  final currentUserId = authService.currentUser?.uid;
  final isOwnProfile = currentUserId == userId;
  final tabsCount = isOwnProfile ? 4 : 3;
  final isDark = Theme.of(parentContext).brightness == Brightness.dark;

  showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
    ),
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: tabsCount,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: const Color(0xFFEC008C),
                  labelColor: const Color(0xFFEC008C),
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                  tabs: [
                    Tab(text: tr ? 'Arkadaşlar' : 'Friends'),
                    Tab(text: tr ? 'Takip Edilenler' : 'Following'),
                    Tab(text: tr ? 'Takipçiler' : 'Followers'),
                    if (isOwnProfile) Tab(text: tr ? 'Engellenenler' : 'Blocked'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Friends Tab
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFriendsList(userId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final list = snap.data ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Text(
                                tr ? 'Henüz arkadaş yok' : 'No friends yet',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            );
                          }
                          return ListView.builder(
                            key: const PageStorageKey('messages_friends_scroll'),
                            controller: scrollController,
                            itemCount: list.length,
                            itemBuilder: (context, idx) {
                              final user = list[idx];
                              return ListTile(
                                leading: _buildAvatarHelper(user.avatarId, user.avatarFrameColor, size: 36),
                                title: Text(
                                  user.username.isEmpty ? user.displayName : '@${user.username}',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(user.displayName, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                onTap: () {
                                  final currentPath = GoRouterState.of(parentContext).uri.toString();
                                  Navigator.of(context).pop();
                                  if (user.username.isNotEmpty) {
                                    parentContext.go('/u/${user.username}?from=${Uri.encodeComponent(currentPath)}');
                                  } else {
                                    parentContext.go('/users/${user.id}?from=${Uri.encodeComponent(currentPath)}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      // Following Tab
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFollowingList(userId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final list = snap.data ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Text(
                                tr ? 'Kimse takip edilmiyor' : 'Not following anyone',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: list.length,
                            itemBuilder: (context, idx) {
                              final user = list[idx];
                              return ListTile(
                                leading: _buildAvatarHelper(user.avatarId, user.avatarFrameColor, size: 36),
                                title: Text(
                                  user.username.isEmpty ? user.displayName : '@${user.username}',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(user.displayName, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                onTap: () {
                                  final currentPath = GoRouterState.of(parentContext).uri.toString();
                                  Navigator.of(context).pop();
                                  if (user.username.isNotEmpty) {
                                    parentContext.go('/u/${user.username}?from=${Uri.encodeComponent(currentPath)}');
                                  } else {
                                    parentContext.go('/users/${user.id}?from=${Uri.encodeComponent(currentPath)}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      // Followers Tab
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFollowersList(userId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final list = snap.data ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Text(
                                tr ? 'Takipçi yok' : 'No followers yet',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: list.length,
                            itemBuilder: (context, idx) {
                              final user = list[idx];
                              return ListTile(
                                leading: _buildAvatarHelper(user.avatarId, user.avatarFrameColor, size: 36),
                                title: Text(
                                  user.username.isEmpty ? user.displayName : '@${user.username}',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(user.displayName, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                onTap: () {
                                  final currentPath = GoRouterState.of(parentContext).uri.toString();
                                  Navigator.of(context).pop();
                                  if (user.username.isNotEmpty) {
                                    parentContext.go('/u/${user.username}?from=${Uri.encodeComponent(currentPath)}');
                                  } else {
                                    parentContext.go('/users/${user.id}?from=${Uri.encodeComponent(currentPath)}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),

                      if (isOwnProfile)
                        // Blocked Tab
                        StreamBuilder<List<AppUser>>(
                          stream: socialRepository.watchBlockedUsersList(userId),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final list = snap.data ?? [];
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  tr ? 'Engellenen kimse yok' : 'No blocked users',
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              );
                            }
                            return ListView.builder(
                              controller: scrollController,
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final user = list[idx];
                                return ListTile(
                                  leading: _buildAvatarHelper(user.avatarId, user.avatarFrameColor, size: 36),
                                  title: Text(
                                    user.username.isEmpty ? user.displayName : '@${user.username}',
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(user.displayName, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                  trailing: TextButton(
                                    onPressed: () async {
                                      final confirmed = await _showGothicConfirmDialog(
                                        context,
                                        title: tr ? 'Engeli Kaldır' : 'Unblock',
                                        content: tr
                                            ? '${user.username.isEmpty ? user.displayName : "@" + user.username} kullanıcısının engelini kaldırmak istediğinize emin misiniz?'
                                            : 'Are you sure you want to unblock ${user.username.isEmpty ? user.displayName : "@" + user.username}?',
                                      );
                                      if (!confirmed) return;
                                      await socialRepository.unblockUser(
                                        blockerId: userId,
                                        blockedId: user.id,
                                      );
                                    },
                                    child: Text(tr ? 'Engeli Kaldır' : 'Unblock', style: const TextStyle(color: Color(0xFFEC008C))),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}



void _showReportsModal(BuildContext context, String userId) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
    ),
    builder: (context) {
      final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr ? 'Raporlarım' : 'My Reports',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<UserReport>>(
                    stream: reportService.watchReportsForUser(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            tr ? 'Henüz bildirilmiş bir şikayet yok.' : 'No reports filed yet.',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final report = list[index];
                          return FutureBuilder<String>(
                            future: _resolveReportTargetText(report),
                            builder: (context, targetSnap) {
                              final targetText = targetSnap.data ?? report.targetId;
                              final statusColor = switch (report.status) {
                                ReportStatus.open => Colors.orange,
                                ReportStatus.reviewing => Colors.purpleAccent,
                                ReportStatus.resolved => Colors.green,
                                ReportStatus.dismissed => Colors.grey,
                              };
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _buildNeonFlagIcon(context, size: 20),
                                title: Text(
                                  '${_reportReasonLabel(context, report.reason)}: $targetText',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  report.details.isNotEmpty ? report.details : (tr ? 'Detay yok' : 'No details'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor, width: 1),
                                  ),
                                  child: Text(
                                    _reportStatusLabel(context, report.status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ----------------------------------------------------
// Announcement Features
// ----------------------------------------------------







void _showCommentsSheet(BuildContext context, String targetId, {String? catalogEntryId}) {
  final currentUser = authService.currentUser;
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final commentController = TextEditingController();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GothicIvyContainer(
          borderRadius: 20,
          color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF2FF),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr ? 'Yorumlar' : 'Comments',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFFEC008C),
                ),
              ),
              const SizedBox(height: 12),
              // Yorum Ekleme Kutusu
              if (currentUser != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: GothicIvyContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: 12,
                        color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF2FF),
                        child: TextField(
                          controller: commentController,
                          maxLines: null,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                            fontFamily: 'Outfit',
                          ),
                          decoration: InputDecoration(
                            hintText: tr ? 'Gotik bir yorum bırak...' : 'Leave a gothic comment...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 13,
                              fontFamily: 'Outfit',
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Gönder Butonu
                    _buildGothicNeonIconButton(
                      context: context,
                      icon: Icons.send_rounded,
                      size: 18,
                      padding: const EdgeInsets.all(8),
                      onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;

                          String senderUsername = currentUser.displayName ?? 'Collector';
                          String senderAvatarId = '';
                          String senderFrameColor = '';
                          try {
                            final doc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .get();
                            final data = doc.data();
                            final customUsername = data?['username'] as String? ?? '';
                            if (customUsername.isNotEmpty) {
                              senderUsername = '@$customUsername';
                            }
                            senderAvatarId = data?['avatarId'] as String? ?? '';
                            senderFrameColor = data?['avatarFrameColor'] as String? ?? '';
                          } catch (_) {}

                          final comment = AppComment(
                            id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
                            targetType: 'collectionEntry',
                            targetId: targetId,
                            userId: currentUser.uid,
                            text: text,
                            sharedCatalogEntryId: catalogEntryId ?? '',
                            senderUsername: senderUsername,
                            senderAvatarId: senderAvatarId,
                            senderFrameColor: senderFrameColor,
                          );
                          await commentRepository.add(comment);
                          commentController.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
              ],
              // Yorumlar Listesi
              Flexible(
                child: StreamBuilder<List<AppComment>>(
                  stream: commentRepository.watchForTarget(
                    targetType: 'collectionEntry',
                    targetId: targetId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC008C)),
                        ),
                      );
                    }

                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(
                            tr ? 'Henüz yorum yok.' : 'No comments yet.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final formattedTime = '${comment.createdAt.hour.toString().padLeft(2, '0')}:${comment.createdAt.minute.toString().padLeft(2, '0')} - ${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}';
                          final isOwnComment = currentUser?.uid == comment.userId;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Close comments bottom sheet
                                    if (comment.senderUsername.isNotEmpty) {
                                      final uName = comment.senderUsername.replaceAll('@', '');
                                      context.go('/u/$uName');
                                    } else {
                                      context.go('/users/${comment.userId}');
                                    }
                                  },
                                  child: _buildAvatarHelper(
                                    comment.senderAvatarId,
                                    comment.senderFrameColor,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context); // Close comments bottom sheet
                                          if (comment.senderUsername.isNotEmpty) {
                                            final uName = comment.senderUsername.replaceAll('@', '');
                                            context.go('/u/$uName');
                                          } else {
                                            context.go('/users/${comment.userId}');
                                          }
                                        },
                                        child: Text(
                                          comment.senderUsername.isEmpty ? 'Collector' : comment.senderUsername,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isDark ? const Color(0xDEFFFFFF) : Colors.black87,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        comment.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Yorum Silme (Kendi yorumuysa)
                                if (isOwnComment) ...[
                                   const SizedBox(width: 4),
                                   _buildGothicNeonIconButton(
                                     context: context,
                                     icon: Icons.delete_forever_rounded,
                                     size: 14,
                                     padding: const EdgeInsets.all(6),
                                     onPressed: () async {
                                       final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                        final confirmed = await _showGothicConfirmDialog(
                                          context,
                                          title: tr ? 'Yorumu Sil' : 'Delete Comment',
                                          content: tr
                                              ? 'Bu yorumu silmek istediğinize emin misiniz?'
                                              : 'Are you sure you want to delete this comment?',
                                        );
                                        if (confirmed) {
                                          await commentRepository.delete(comment.id);
                                        }
                                     },
                                   ),
                                 ],
                                const SizedBox(width: 6),
                                // Beğeni Butonu
                                StreamBuilder<int>(
                                  stream: socialRepository.watchLikesCount('comment', comment.id),
                                  builder: (context, commentLikesSnap) {
                                    final likeCount = commentLikesSnap.data ?? 0;
                                    return StreamBuilder<bool>(
                                      stream: currentUser != null
                                          ? socialRepository.watchIsLiked(currentUser.uid, 'comment', comment.id)
                                          : Stream.value(false),
                                      builder: (context, commentIsLikedSnap) {
                                        final isCommentLiked = commentIsLikedSnap.data ?? false;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildGothicNeonIconButton(
                                              context: context,
                                              icon: isCommentLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              size: 12,
                                              padding: const EdgeInsets.all(6),
                                              onPressed: currentUser == null
                                                  ? null
                                                  : () async {
                                                      if (isCommentLiked) {
                                                        await socialRepository.unlikeTarget(
                                                          userId: currentUser.uid,
                                                          targetType: "comment",
                                                          targetId: comment.id,
                                                        );
                                                      } else {
                                                        await socialRepository.likeTarget(
                                                          userId: currentUser.uid,
                                                          targetType: "comment",
                                                          targetId: comment.id,
                                                        );
                                                      }
                                                    },
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$likeCount',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : Colors.black87,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                // Raporla Butonu (Bayrak)
                                _buildGothicNeonIconButton(
                                  context: context,
                                  icon: Icons.flag_rounded,
                                  size: 14,
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () {
                                    _showReportSheet(
                                      context,
                                      ReportTargetType.comment,
                                      comment.id,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showPhotoGalleryDialog(BuildContext context, List<String> imageUrls, int initialIndex) {
  if (imageUrls.isEmpty) return;
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.9),
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Resimler
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: DollImage(
                        imageUrl: imageUrls[index],
                        label: 'Gallery $index',
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Kapat Butonu
            Positioned(
              top: 10,
              right: 10,
              child: ClipOval(
                child: Container(
                  color: Colors.black54,
                  child: IconButton(
                    icon: _buildNeonIcon(context, Icons.close_rounded, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}







// ==========================================
// DIRECT MESSAGES (DM) MODAL IMPLEMENTATION
// ==========================================

void _openDirectMessagesModal(BuildContext context, {String? initialChatUserId}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF0F0918) : const Color(0xFFFAF2FF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: DirectMessagesModalContent(initialChatUserId: initialChatUserId),
      );
    },
  );
}

void _openDirectChatWithUser(BuildContext context, String otherUserId) {
  _openDirectMessagesModal(context, initialChatUserId: otherUserId);
}













void showCollectionSheet(BuildContext context, CatalogEntry item) => _showCollectionSheet(context, item);
void showProSubscriptionModal(BuildContext context) => _showProSubscriptionModal(context);
void showReportSheet(BuildContext context, ReportTargetType targetType, String targetId) => _showReportSheet(context, targetType, targetId);
CatalogEntry findCatalogEntry(String id) => _findCatalogEntry(id);
List<CatalogEntry> filterCatalogEntries(List<CatalogEntry> entries, String query, CatalogItemType? type) => _filterCatalogEntries(entries, query, type);
void openDirectMessagesModal(BuildContext context, {String? initialChatUserId}) => _openDirectMessagesModal(context, initialChatUserId: initialChatUserId);
void openDirectChatWithUser(BuildContext context, String otherUserId) => _openDirectChatWithUser(context, otherUserId);
void showChangeUsernameDialog(BuildContext context, String userId) => _showChangeUsernameDialog(context, userId);
void showReportsModal(BuildContext context, String userId) => _showReportsModal(context, userId);
void showAvatarStudioModal(BuildContext context, String userId) => _showAvatarStudioModal(context, userId);
void showConnectionsModal(BuildContext context, String userId) => _showConnectionsModal(context, userId);
void showCommentsSheet(BuildContext context, String targetId, {String? catalogEntryId}) => _showCommentsSheet(context, targetId, catalogEntryId: catalogEntryId);
Future<void> saveCatalogDraft(BuildContext context, CatalogEntryDraft draft) => _saveCatalogDraft(context, draft);
void deleteCatalogEntry(String id) => _deleteCatalogEntry(id);
Future<void> deleteReportedContent(BuildContext context, UserReport report) => _deleteReportedContent(context, report);
void updateReportStatus(String id, ReportStatus status) => _updateReportStatus(id, status);
void deleteReport(String id) => _deleteReport(id);
void openReportTarget(BuildContext context, UserReport report) => _openReportTarget(context, report);
Future<String> resolveReportTargetText(UserReport report) => _resolveReportTargetText(report);
bool isTemplateEntry(CatalogEntry entry) => _isTemplateEntry(entry);
void addAppNotification(String text) => _addAppNotification(text);

Future<void> performGoogleSignIn(BuildContext context) async {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  try {
    final userCredential = await authService.signInWithGoogle();
    final newUser = userCredential.user;
    if (newUser != null) {
      final localEntries = collectionEntriesNotifier.value
          .where((entry) => entry.userId == 'local-user')
          .toList();
      if (localEntries.isNotEmpty) {
        for (final localEntry in localEntries) {
          final migratedEntry = CollectionEntry(
            id: '${newUser.uid}-${localEntry.itemId}',
            userId: newUser.uid,
            itemId: localEntry.itemId,
            status: localEntry.status,
            condition: localEntry.condition,
            quantity: localEntry.quantity,
            notes: localEntry.notes,
            isPublic: localEntry.isPublic,
          );
          await collectionRepository.save(migratedEntry);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr
                    ? '${localEntries.length} parça hesabınıza aktarıldı!'
                    : '${localEntries.length} items migrated to your account!',
              ),
            ),
          );
        }
      }
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr
                ? 'Giriş yapılamadı: $error'
                : 'Sign in failed: $error',
          ),
        ),
      );
    }
  }
}

