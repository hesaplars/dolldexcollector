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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    FlutterError.presentError(details);
    final errStr = 'Framework Error: ${details.exception}\n\n${details.stack}';
    Future.microtask(() {
      appErrorNotifier.value = errStr;
    });
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
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
          return ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeController,
            builder: (context, themeMode, _) {
              return MaterialApp.router(
                title: 'DollDex Collector',
                debugShowCheckedModeBanner: false,
                theme: DollDexTheme.light,
                darkTheme: DollDexTheme.dark,
                themeMode: themeMode,
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

class GothicBackgroundPainter extends CustomPainter {
  const GothicBackgroundPainter({required this.themeBrightness});
  final Brightness themeBrightness;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = themeBrightness == Brightness.dark;
    
    // Radial gradient background
    final rect = Offset.zero & size;
    final paintBg = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF1B0F2A), const Color(0xFF07040B)]
            : [const Color(0xFFE5DDF2), const Color(0xFFC7B8E0)],
        center: Alignment.center,
        radius: 1.0,
      ).createShader(rect);
    canvas.drawRect(rect, paintBg);

    // Draw scattered gothic motifs (yarasalar, bal kabakları, kalpler, hilaller, kuru kafalar, örümcek ağları, tabutlar, anahtarlar)
    final paintMotif = Paint()
      ..color = (isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C)).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final random = math.Random(12345); // deterministic seed
    final count = 30;
    for (int i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final scale = 15.0 + random.nextDouble() * 15.0;
      final rotation = random.nextDouble() * math.pi * 2;
      final type = random.nextInt(8); // 8 types of motifs

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final path = Path();
      switch (type) {
        case 0: // Bat
          path.moveTo(0, -scale * 0.2);
          path.quadraticBezierTo(scale * 0.4, -scale * 0.5, scale * 0.8, -scale * 0.2);
          path.quadraticBezierTo(scale * 0.5, scale * 0.1, scale * 0.2, 0);
          path.quadraticBezierTo(0, scale * 0.3, -scale * 0.2, 0);
          path.quadraticBezierTo(-scale * 0.5, scale * 0.1, -scale * 0.8, -scale * 0.2);
          path.quadraticBezierTo(-scale * 0.4, -scale * 0.5, 0, -scale * 0.2);
          break;
        case 1: // Pumpkin
          path.addOval(Rect.fromCenter(center: Offset.zero, width: scale, height: scale * 0.8));
          path.moveTo(0, -scale * 0.4);
          path.quadraticBezierTo(scale * 0.1, -scale * 0.6, scale * 0.2, -scale * 0.5);
          break;
        case 2: // Heart
          path.moveTo(0, -scale * 0.3);
          path.cubicTo(scale * 0.4, -scale * 0.8, scale * 0.9, -scale * 0.2, 0, scale * 0.5);
          path.cubicTo(-scale * 0.9, -scale * 0.2, -scale * 0.4, -scale * 0.8, 0, -scale * 0.3);
          break;
        case 3: // Crescent Moon
          path.addArc(Rect.fromCenter(center: Offset.zero, width: scale, height: scale), -math.pi / 2, math.pi);
          path.quadraticBezierTo(scale * 0.2, 0, 0, -scale / 2);
          break;
        case 4: // Skull
          path.addArc(Rect.fromCenter(center: const Offset(0, -2), width: scale * 0.7, height: scale * 0.7), math.pi, math.pi);
          path.lineTo(scale * 0.25, scale * 0.3);
          path.lineTo(-scale * 0.25, scale * 0.3);
          path.close();
          break;
        case 5: // Spiderweb
          for (double r = 0.2; r <= 1.0; r += 0.4) {
            path.addOval(Rect.fromCenter(center: Offset.zero, width: scale * r, height: scale * r));
          }
          path.moveTo(-scale / 2, -scale / 2);
          path.lineTo(scale / 2, scale / 2);
          path.moveTo(scale / 2, -scale / 2);
          path.lineTo(-scale / 2, scale / 2);
          break;
        case 6: // Coffin
          path.moveTo(0, -scale * 0.5);
          path.lineTo(scale * 0.35, -scale * 0.3);
          path.lineTo(scale * 0.25, scale * 0.5);
          path.lineTo(-scale * 0.25, scale * 0.5);
          path.lineTo(-scale * 0.35, -scale * 0.3);
          path.close();
          break;
        case 7: // Antique Key
          path.addOval(Rect.fromCenter(center: Offset(0, -scale * 0.25), width: scale * 0.4, height: scale * 0.4));
          path.moveTo(0, -scale * 0.05);
          path.lineTo(0, scale * 0.5);
          path.moveTo(0, scale * 0.3);
          path.lineTo(scale * 0.2, scale * 0.3);
          path.moveTo(0, scale * 0.45);
          path.lineTo(scale * 0.25, scale * 0.45);
          break;
      }
      canvas.drawPath(path, paintMotif);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IvyBorderPainter extends CustomPainter {
  const IvyBorderPainter({required this.color, this.borderRadius = 12.0});
  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final r = borderRadius;
    final w = size.width;
    final h = size.height;

    // Ivy border path construction
    path.moveTo(r, 0);
    path.quadraticBezierTo(w * 0.25, -1, w * 0.5, 1);
    path.quadraticBezierTo(w * 0.75, 2, w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);
    path.quadraticBezierTo(w + 1, h * 0.25, w - 1, h * 0.5);
    path.quadraticBezierTo(w - 2, h * 0.75, w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r), clockwise: true);
    path.quadraticBezierTo(w * 0.75, h + 1, w * 0.5, h - 1);
    path.quadraticBezierTo(w * 0.25, h - 2, r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r), clockwise: true);
    path.quadraticBezierTo(-1, h * 0.75, 1, h * 0.5);
    path.quadraticBezierTo(2, h * 0.25, 0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

    canvas.drawPath(path, paint);

    final leafPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    void drawLeaf(double x, double y, double angle) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final leaf = Path();
      leaf.moveTo(0, 0);
      leaf.quadraticBezierTo(5, -4, 10, 0);
      leaf.quadraticBezierTo(5, 4, 0, 0);
      canvas.drawPath(leaf, leafPaint);
      canvas.restore();
    }

    void drawSpike(double x, double y, double angle) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final spike = Path();
      spike.moveTo(0, 0);
      spike.quadraticBezierTo(2, -3, -1, -5);
      canvas.drawPath(spike, paint);
      canvas.restore();
    }

    // Ivy leaves and spikes
    drawLeaf(w * 0.2, 0, -math.pi / 6);
    drawSpike(w * 0.35, 1, math.pi / 4);
    drawLeaf(w * 0.65, 1, math.pi / 6);
    drawSpike(w * 0.8, 0, -math.pi / 4);

    drawLeaf(w, h * 0.3, math.pi / 3);
    drawSpike(w - 1, h * 0.45, math.pi / 2);
    drawLeaf(w - 1, h * 0.7, 2 * math.pi / 3);

    drawLeaf(w * 0.3, h, 7 * math.pi / 6);
    drawSpike(w * 0.5, h - 1, 5 * math.pi / 4);
    drawLeaf(w * 0.75, h - 1, 5 * math.pi / 6);

    drawLeaf(0, h * 0.35, -math.pi / 3);
    drawSpike(1, h * 0.55, -math.pi / 2);
    drawLeaf(1, h * 0.8, -2 * math.pi / 3);
  }

  @override
  bool shouldRepaint(covariant IvyBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

class GothicIvyContainer extends StatelessWidget {
  const GothicIvyContainer({
    required this.child,
    this.borderRadius = 12.0,
    this.color,
    this.borderColor,
    this.padding,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = color ?? (isDark ? const Color(0xFF160E22) : const Color(0xFFFAF6FC));
    final borderCol = borderColor ?? (isDark
        ? const Color(0xFF00FFCC).withOpacity(0.4)
        : const Color(0xFFEC008C).withOpacity(0.5));

    return Container(
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: CustomPaint(
        painter: IvyBorderPainter(color: borderCol, borderRadius: borderRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(4.0),
          child: child,
        ),
      ),
    );
  }
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Animation<double>? _pulseRepeatAnimation;
  late AnimationController _pulseRepeatController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _repeatPulse();
      }
    });

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  void _repeatPulse() {
    _pulseRepeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    setState(() {
      _pulseRepeatAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _pulseRepeatController, curve: Curves.easeInOut),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    try {
      _pulseRepeatController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          final double scaleVal = _pulseRepeatAnimation != null
              ? _pulseRepeatAnimation!.value
              : _pulseAnimation.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: GothicBackgroundPainter(themeBrightness: Theme.of(context).brightness),
              ),
              const GothicPageBackgroundWidget(),

              // Central Pulsing App Name
              Center(
                child: Transform.scale(
                  scale: scaleVal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SafeShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: const Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SafeShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Text(
                          t(context, 'appName'),
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFFEC008C),
                                blurRadius: 15,
                              ),
                              Shadow(
                                color: Color(0xFF00FFCC),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLanguageScope.languageOf(context) == AppLanguage.tr
                            ? 'Gotik Koleksiyon Dünyası'
                            : 'Gothic Collection World',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFFC4B2D9) : const Color(0xFF6B5885),
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          path: '/',
          builder: (context, state) => const CatalogScreen(),
        ),
        GoRoute(
          path: '/catalog/:id',
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
          builder: (context, state) => const ProfileScreen(),
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
            final chatUserId = state.uri.queryParameters['chatUserId'];
            return SocialScreen(chatUserId: chatUserId);
          },
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const MessagesScreen(),
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
          path: '/collection/entry/:id',
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

class GothicFrameWidget extends StatelessWidget {
  const GothicFrameWidget({required this.frameType, required this.size, super.key});

  final String frameType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GothicFramePainter(frameType: frameType),
      ),
    );
  }
}

class GothicFramePainter extends CustomPainter {
  GothicFramePainter({required this.frameType});

  final String frameType;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (frameType == 'frame-0') {
      // 1. Thorny Ivy (Neon Green)
      paint.color = const Color(0xFF00FFCC);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final thornPaint = Paint()
        ..color = const Color(0xFF43AA8B)
        ..style = PaintingStyle.fill;
        
      for (int i = 0; i < 8; i++) {
        final angle = (i * 45) * math.pi / 180;
        final thornTip = Offset(
          center.dx + (radius + 2.5) * math.cos(angle),
          center.dy + (radius + 2.5) * math.sin(angle),
        );
        final base1 = Offset(
          center.dx + (radius - 3.5) * math.cos(angle - 0.1),
          center.dy + (radius - 3.5) * math.sin(angle - 0.1),
        );
        final base2 = Offset(
          center.dx + (radius - 3.5) * math.cos(angle + 0.1),
          center.dy + (radius - 3.5) * math.sin(angle + 0.1),
        );
        final path = Path()
          ..moveTo(base1.dx, base1.dy)
          ..lineTo(thornTip.dx, thornTip.dy)
          ..lineTo(base2.dx, base2.dy)
          ..close();
        canvas.drawPath(path, thornPaint);
      }
    } else if (frameType == 'frame-1') {
      // 2. Bat Swarm (Neon Magenta)
      paint.color = const Color(0xFFEC008C);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final batPaint = Paint()
        ..color = const Color(0xFF7B2CBF)
        ..style = PaintingStyle.fill;
        
      // Left and Right bat ornaments
      for (final isRight in [false, true]) {
        final sign = isRight ? 1.0 : -1.0;
        final batCenter = Offset(center.dx + sign * (radius), center.dy);
        canvas.save();
        canvas.translate(batCenter.dx, batCenter.dy);
        
        final path = Path()
          ..moveTo(0, -2)
          ..quadraticBezierTo(sign * 3, -6, sign * 8, -2)
          ..quadraticBezierTo(sign * 5, 2, 0, 3)
          ..quadraticBezierTo(sign * -5, 2, sign * -8, -2)
          ..quadraticBezierTo(sign * -3, -6, 0, -2)
          ..close();
        canvas.drawPath(path, batPaint);
        
        // Glow points
        final glowPaint = Paint()..color = const Color(0xFF00FFCC)..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(sign * 1.5, -2), 0.5, glowPaint);
        canvas.restore();
      }
    } else if (frameType == 'frame-2') {
      // 3. Spider Web (Neon Teal)
      paint.color = const Color(0xFF00FFCC);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final webPaint = Paint()
        ..color = const Color(0xFF00FFCC).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
        
      for (int i = 0; i < 4; i++) {
        final angle = (i * 45) * math.pi / 180;
        canvas.drawLine(
          Offset(center.dx - radius * math.cos(angle), center.dy - radius * math.sin(angle)),
          Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
          webPaint,
        );
      }
    } else if (frameType == 'frame-3') {
      // 4. Creepy Skulls (Bone White & Glow)
      paint.color = const Color(0xFFF5EBFD);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final skullPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final eyePaint = Paint()
        ..color = const Color(0xFF0E0818)
        ..style = PaintingStyle.fill;

      // Draw 4 small skull charms on top/bottom/left/right
      final positions = [
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy)
      ];

      for (final pos in positions) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        
        // Skull main head
        canvas.drawCircle(Offset.zero, 3.5, skullPaint);
        // Skull jaw
        canvas.drawRect(Rect.fromLTWH(-2, 2.5, 4, 3), skullPaint);
        // Eyes
        canvas.drawCircle(Offset(-1.2, 0), 1.0, eyePaint);
        canvas.drawCircle(Offset(1.2, 0), 1.0, eyePaint);
        
        canvas.restore();
      }
    } else if (frameType == 'frame-4') {
      // 5. Black Roses & Red Buds
      paint.color = const Color(0xFF2C1F45);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final rosePaint = Paint()
        ..color = const Color(0xFF0D0D0D)
        ..style = PaintingStyle.fill;
      final budPaint = Paint()
        ..color = const Color(0xFFBC4749)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 6; i++) {
        final angle = (i * 60) * math.pi / 180;
        final rosePos = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        // Black rose base
        canvas.drawCircle(rosePos, 4.0, rosePaint);
        // Red bud center
        canvas.drawCircle(rosePos, 2.0, budPaint);
      }
    } else if (frameType == 'frame-5') {
      // 6. Crown of Thorns (Neon Purple Spike-Ring)
      paint.color = const Color(0xFF8338EC);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final spikePaint = Paint()
        ..color = const Color(0xFFEC008C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (int i = 0; i < 16; i++) {
        final angle = (i * 22.5) * math.pi / 180;
        final start = Offset(
          center.dx + (radius - 2) * math.cos(angle),
          center.dy + (radius - 2) * math.sin(angle),
        );
        // Alternate spike directions inside and outside
        final offsetLen = (i % 2 == 0) ? 4.0 : -3.0;
        final end = Offset(
          center.dx + (radius + offsetLen) * math.cos(angle + 0.1),
          center.dy + (radius + offsetLen) * math.sin(angle + 0.1),
        );
        canvas.drawLine(start, end, spikePaint);
      }
    } else if (frameType == 'frame-6') {
      // 7. Gothic Crosses (Neon Fuschia)
      paint.color = const Color(0xFFEC008C);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final crossPaint = Paint()
        ..color = const Color(0xFFEC008C)
        ..style = PaintingStyle.fill;

      // Draw small gothic crosses at 4 diagonal corners
      for (int i = 0; i < 4; i++) {
        final angle = (45 + i * 90) * math.pi / 180;
        final crossPos = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        canvas.save();
        canvas.translate(crossPos.dx, crossPos.dy);
        canvas.rotate(angle);
        
        // Vertical beam
        canvas.drawRect(Rect.fromLTWH(-1.2, -4.5, 2.4, 9), crossPaint);
        // Horizontal beam
        canvas.drawRect(Rect.fromLTWH(-3.5, -2, 7, 2), crossPaint);
        
        canvas.restore();
      }
    } else if (frameType == 'frame-7') {
      // 8. Gargoyle Wings (Stone Grey / Luminous Purple)
      paint.color = const Color(0xFF6D597A);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final wingPaint = Paint()
        ..color = const Color(0xFF4A2840)
        ..style = PaintingStyle.fill;

      // Wing ornaments at left-bottom and right-bottom
      for (final isRight in [false, true]) {
        final sign = isRight ? 1.0 : -1.0;
        final wingPos = Offset(center.dx + sign * radius, center.dy + 8);
        canvas.save();
        canvas.translate(wingPos.dx, wingPos.dy);
        canvas.rotate(sign * 25 * math.pi / 180);
        
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(sign * 6, -10, sign * 12, -2)
          ..quadraticBezierTo(sign * 8, 3, 0, 5)
          ..close();
        canvas.drawPath(path, wingPaint);
        canvas.restore();
      }
    } else if (frameType == 'frame-8') {
      // 9. Gothic Dragon/Demonic Wings (Neon Blue/Violet)
      paint.color = const Color(0xFF00B4D8);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final dragonPaint = Paint()
        ..color = const Color(0xFF8338EC)
        ..style = PaintingStyle.fill;

      // High wings at top-left and top-right
      for (final isRight in [false, true]) {
        final sign = isRight ? 1.0 : -1.0;
        final wingPos = Offset(center.dx + sign * (radius - 2), center.dy - 12);
        canvas.save();
        canvas.translate(wingPos.dx, wingPos.dy);
        canvas.rotate(-sign * 35 * math.pi / 180);
        
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(sign * -4, -12, sign * -14, -6)
          ..quadraticBezierTo(sign * -8, 2, 0, 2)
          ..close();
        canvas.drawPath(path, dragonPaint);
        canvas.restore();
      }
    } else if (frameType == 'frame-9') {
      // 10. Crescent Moon & Stars (Luminous Amber / Cyan)
      paint.color = const Color(0xFFE5A93A);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final moonPaint = Paint()
        ..color = const Color(0xFFE5A93A)
        ..style = PaintingStyle.fill;
      final starPaint = Paint()
        ..color = const Color(0xFF00FFCC)
        ..style = PaintingStyle.fill;

      // Large crescent moon at top-right
      canvas.save();
      canvas.translate(center.dx + radius * 0.7, center.dy - radius * 0.7);
      final moonPath = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 5.0));
      final cutPath = Path()
        ..addOval(Rect.fromCircle(center: const Offset(-2.0, -1.0), radius: 4.5));
      final finalMoon = Path.combine(PathOperation.difference, moonPath, cutPath);
      canvas.drawPath(finalMoon, moonPaint);
      canvas.restore();

      // Tiny stars at top-left
      canvas.drawCircle(Offset(center.dx - radius * 0.7, center.dy - radius * 0.7), 1.2, starPaint);
      canvas.drawCircle(Offset(center.dx - radius * 0.5, center.dy - radius * 0.8), 0.8, starPaint);
    } else if (frameType == 'frame-10') {
      // 11. Tabuts/Coffins Frame (Dark Crimson)
      paint.color = const Color(0xFFBC4749);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final coffinPaint = Paint()
        ..color = const Color(0xFF3B0000)
        ..style = PaintingStyle.fill;
      final crossLinePaint = Paint()
        ..color = const Color(0xFFBC4749)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      // 4 mini coffins on diagonals
      for (int i = 0; i < 4; i++) {
        final angle = (45 + i * 90) * math.pi / 180;
        final pos = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle);

        // Coffin polygon
        final path = Path()
          ..moveTo(0, -4.5)
          ..lineTo(2.2, -2.5)
          ..lineTo(1.8, 4.5)
          ..lineTo(-1.8, 4.5)
          ..lineTo(-2.2, -2.5)
          ..close();
        canvas.drawPath(path, coffinPaint);
        
        // Coffin cross detail
        canvas.drawLine(const Offset(0, -2.5), const Offset(0, 2.5), crossLinePaint);
        canvas.drawLine(const Offset(-1.2, -0.5), const Offset(1.2, -0.5), crossLinePaint);

        canvas.restore();
      }
    } else if (frameType == 'frame-11') {
      // 12. Mystical Black Cat (Deep Violet Ear & Paw points)
      paint.color = const Color(0xFF7B2CBF);
      canvas.drawCircle(center, radius - 1.5, paint);
      
      final catPaint = Paint()
        ..color = const Color(0xFF160E22)
        ..style = PaintingStyle.fill;
      final innerEarPaint = Paint()
        ..color = const Color(0xFFEC008C)
        ..style = PaintingStyle.fill;

      // Cat Ears at top
      // Left Ear
      canvas.save();
      canvas.translate(center.dx - 8, center.dy - radius + 1);
      final leftEar = Path()
        ..moveTo(-3, 1)
        ..lineTo(0, -6)
        ..lineTo(3, 2)
        ..close();
      canvas.drawPath(leftEar, catPaint);
      final leftInner = Path()
        ..moveTo(-1.5, 1)
        ..lineTo(0, -3.5)
        ..lineTo(1.5, 1.5)
        ..close();
      canvas.drawPath(leftInner, innerEarPaint);
      canvas.restore();

      // Right Ear
      canvas.save();
      canvas.translate(center.dx + 8, center.dy - radius + 1);
      final rightEar = Path()
        ..moveTo(-3, 2)
        ..lineTo(0, -6)
        ..lineTo(3, 1)
        ..close();
      canvas.drawPath(rightEar, catPaint);
      final rightInner = Path()
        ..moveTo(-1.5, 1.5)
        ..lineTo(0, -3.5)
        ..lineTo(1.5, 1)
        ..close();
      canvas.drawPath(rightInner, innerEarPaint);
      canvas.restore();
    } else {
      paint.color = const Color(0xFFEC008C);
      canvas.drawCircle(center, radius - 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GothicBorderContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderWidth;
  final Color backgroundColor;

  const GothicBorderContainer({
    required this.child,
    this.padding,
    this.borderWidth = 10.0,
    this.backgroundColor = const Color(0xFF0E0818),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GothicCardBorderPainter(),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: padding ?? EdgeInsets.all(borderWidth + 4),
        child: child,
      ),
    );
  }
}

class GothicCardBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    
    // 1. Kenarlardaki Dikenli Sarmaşıklar (Neon Pembe)
    final vinePaint = Paint()
      ..color = const Color(0xFFEC008C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect.deflate(2.0), vinePaint);

    // Dikenler (Sarmaşık üzerindeki çıkıntılar)
    final thornPaint = Paint()
      ..color = const Color(0xFFEC008C)
      ..style = PaintingStyle.fill;

    // Kenarlar boyunca dikenler çizelim
    // Üst kenar
    for (double x = 40; x < size.width - 40; x += 60) {
      _drawThorn(canvas, Offset(x, 2), 0, thornPaint);
    }
    // Alt kenar
    for (double x = 40; x < size.width - 40; x += 60) {
      _drawThorn(canvas, Offset(x, size.height - 2), math.pi, thornPaint);
    }
    // Sol kenar
    for (double y = 40; y < size.height - 40; y += 60) {
      _drawThorn(canvas, Offset(2, y), -math.pi / 2, thornPaint);
    }
    // Sağ kenar
    for (double y = 40; y < size.height - 40; y += 60) {
      _drawThorn(canvas, Offset(size.width - 2, y), math.pi / 2, thornPaint);
    }

    // 2. Köşelerdeki Yarasalar (Neon Mor)
    final batPaint = Paint()
      ..color = const Color(0xFF7B2CBF)
      ..style = PaintingStyle.fill;

    // Dört köşeye yarasa çizelim
    _drawCornerBat(canvas, Offset(16, 16), batPaint); // Sol Üst
    _drawCornerBat(canvas, Offset(size.width - 16, 16), batPaint); // Sağ Üst
    _drawCornerBat(canvas, Offset(16, size.height - 16), batPaint); // Sol Alt
    _drawCornerBat(canvas, Offset(size.width - 16, size.height - 16), batPaint); // Sağ Alt
  }

  void _drawThorn(Canvas canvas, Offset position, double rotation, Paint paint) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    
    final path = Path()
      ..moveTo(-3, 0)
      ..lineTo(0, -7) // Diken ucu
      ..lineTo(3, 0)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawCornerBat(Canvas canvas, Offset center, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    
    final path = Path()
      ..moveTo(0, -2) // Baş
      ..quadraticBezierTo(-3, -7, -8, -3) // Sol kanat üstü
      ..quadraticBezierTo(-5, 2, 0, 3) // Sol kanat altı
      ..quadraticBezierTo(5, 2, 8, -3) // Sağ kanat üstü
      ..quadraticBezierTo(3, -7, 0, -2) // Baş tarafı kapama
      ..close();

    canvas.drawPath(path, paint);
    
    // Yarasa gözleri (Neon Camgöbeği)
    final eyePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-1.5, -2.5), 0.6, eyePaint);
    canvas.drawCircle(const Offset(1.5, -2.5), 0.6, eyePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DollDexTheme {
  static const ink = Color(0xFF1C0D2B);
  static const paper = Color(0xFFFAF2FF); // Soft gothic cream/lila background
  static const mist = Color(0xFFF5EBFD);  // Panel/background light lila tint
  static const teal = Color(0xFFEC008C);  // Neon Fuschia
  static const berry = Color(0xFF00B4D8); // Bright Turquoise for contrast
  static const amber = Color(0xFFE5A93A);
  static const line = Color(0xFFE9D8FA);
  static const darkInk = Color(0xFFF5F1F7);
  static const darkPaper = Color(0xFF0E0818); // Deep gothic purple background
  static const darkPanel = Color(0xFF171026); // Luminous deep purple panel
  static const darkLine = Color(0xFF2C1F45);

  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        primary: teal,
        secondary: berry,
        surface: paper,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: paper,
      textTheme: GoogleFonts.cinzelTextTheme(base.textTheme).apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: teal.withOpacity(0.15), width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: teal.withOpacity(0.2), width: 1.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: teal.withOpacity(0.2), width: 1.0),
        ),
        dragHandleColor: teal.withOpacity(0.3),
        dragHandleSize: const Size(40, 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: teal,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: teal,
          selectedForegroundColor: Colors.white,
          foregroundColor: ink,
          side: const BorderSide(color: line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mist,
        selectedColor: teal,
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: line, width: 1.2),
        ),
        checkmarkColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? teal : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? teal.withOpacity(0.4) : Colors.grey.withOpacity(0.3),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? teal : Colors.transparent,
        ),
        side: const BorderSide(color: line, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEC008C), width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: teal,
              fontFamily: 'Cinzel',
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ink.withOpacity(0.55),
            fontFamily: 'Cinzel',
          );
        }),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEC008C),
        brightness: Brightness.dark,
        primary: const Color(0xFFEC008C), // Neon Fuschia
        secondary: const Color(0xFF00FFCC), // Neon Turquoise
        surface: darkPanel,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkPaper,
      textTheme: GoogleFonts.cinzelTextTheme(base.textTheme).apply(
        bodyColor: darkInk,
        displayColor: darkInk,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkPaper,
        foregroundColor: darkInk,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: darkPanel,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.25),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.2), width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
        ),
        dragHandleColor: const Color(0xFFEC008C).withOpacity(0.4),
        dragHandleSize: const Size(40, 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEC008C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkInk,
          side: const BorderSide(color: darkLine, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPanel,
          foregroundColor: darkInk,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFEC008C),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFEC008C),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: const Color(0xFFEC008C),
          selectedForegroundColor: Colors.white,
          foregroundColor: darkInk,
          side: const BorderSide(color: darkLine, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkPanel,
        selectedColor: const Color(0xFFEC008C),
        labelStyle: TextStyle(color: darkInk, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: darkLine, width: 1.2),
        ),
        checkmarkColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Color(0xFFEC008C) : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Color(0xFFEC008C).withOpacity(0.4) : Colors.grey.withOpacity(0.3),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Color(0xFFEC008C) : Colors.transparent,
        ),
        side: const BorderSide(color: darkLine, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkPanel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkLine, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEC008C), width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkPaper,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEC008C), // Neon Fuschia
              fontFamily: 'Cinzel',
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: darkInk.withOpacity(0.55),
            fontFamily: 'Cinzel',
          );
        }),
      ),
    );
  }
}

class GothicAdBannerVertical extends StatefulWidget {
  const GothicAdBannerVertical({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.promoCode,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final String description;
  final String promoCode;
  final IconData icon;

  @override
  State<GothicAdBannerVertical> createState() => _GothicAdBannerVerticalState();
}

class _GothicAdBannerVerticalState extends State<GothicAdBannerVertical>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF0E0818).withOpacity(0.85)
        : const Color(0xFFFAF2FF).withOpacity(0.9);
    final borderColor = isDark ? const Color(0xFFEC008C) : const Color(0xFFEC008C).withOpacity(0.7);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
            width: 140,
            height: 480,
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withOpacity(0.4 + _glowAnimation.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC008C).withOpacity(_glowAnimation.value * (_isHovered ? 1.4 : 1.0)),
                  blurRadius: (10 + (_glowAnimation.value * 15)) * (_isHovered ? 1.2 : 1.0),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF00FFCC).withOpacity(_glowAnimation.value * 0.4),
                  blurRadius: 5 + (_glowAnimation.value * 10),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    SafeShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                        ).createShader(bounds);
                      },
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 1,
                      width: 35,
                      color: const Color(0xFF00FFCC).withOpacity(0.5),
                    ),
                  ],
                ),
                Icon(
                  widget.icon,
                  size: 32,
                  color: const Color(0xFF00FFCC).withOpacity(0.85),
                ),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF0E0818),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFEC008C)),
                          ),
                          title: Text(
                            widget.subtitle,
                            style: const TextStyle(fontFamily: 'Cinzel', color: Colors.white),
                          ),
                          content: Text(
                            'DollDex Collector özel indirim kodunuz: ${widget.promoCode}\nKeyifli koleksiyonlar dileriz!',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Kapat', style: TextStyle(color: Color(0xFF00FFCC))),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FFCC), width: 1),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEC008C).withOpacity(_isHovered ? 0.35 : 0.15),
                            const Color(0xFF00FFCC).withOpacity(_isHovered ? 0.35 : 0.15),
                          ],
                        ),
                      ),
                      child: const Text(
                        'KEŞFET',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
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

class GothicAdBannerHorizontal extends StatefulWidget {
  const GothicAdBannerHorizontal({super.key});

  @override
  State<GothicAdBannerHorizontal> createState() => _GothicAdBannerHorizontalState();
}

class _GothicAdBannerHorizontalState extends State<GothicAdBannerHorizontal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.12, end: 0.38).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF0E0818).withOpacity(0.85)
        : const Color(0xFFFAF2FF).withOpacity(0.9);
    final borderColor = isDark ? const Color(0xFFEC008C) : const Color(0xFFEC008C).withOpacity(0.7);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 52,
            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor.withOpacity(0.4 + _glowAnimation.value),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withOpacity(_glowAnimation.value * (_isHovered ? 1.3 : 0.7)),
                  blurRadius: (8 + (_glowAnimation.value * 12)) * (_isHovered ? 1.25 : 1.0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                SafeShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [Color(0xFFEC008C), Color(0xFF00FFCC)],
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DOLLDEX EXCLUSIVE',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEC008C),
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Yeni Gotik Bebek Serisi yayında! Hemen kataloğu inceleyin.',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF0E0818),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF00FFCC)),
                          ),
                          title: const Text(
                            'Sınırlı Sürüm Serisi',
                            style: TextStyle(fontFamily: 'Cinzel', color: Colors.white),
                          ),
                          content: const Text(
                            'Kataloğumuza yeni eklenen özel gotik seriye göz atmak için Kataloğu filtreleyip "Setler" kategorisini inceleyebilirsiniz.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Kapat', style: TextStyle(color: Color(0xFFEC008C))),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEC008C), width: 0.8),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEC008C).withOpacity(_isHovered ? 0.3 : 0.15),
                            const Color(0xFF00FFCC).withOpacity(_isHovered ? 0.3 : 0.15),
                          ],
                        ),
                      ),
                      child: const Text(
                        'İNCELE',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
            child: _buildNeonTopIcon(Icons.chat_bubble_outline_rounded),
          ),
        ),
        label: tr ? 'Mesajlarım' : 'Messages',
      ),
      NavigationDestination(
        icon: Opacity(
          opacity: selectedIndex == 3 ? 1.0 : 0.45,
          child: _buildNeonTopIcon(Icons.people_outline_rounded),
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
                        child: _buildAvatarHelper(
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

    _loadCollectionForCurrentUser();
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

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';
  CatalogItemType? _type;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: t(context, 'catalog'),
      subtitle: t(context, 'catalogSubtitle'),
      child: Column(
        children: [
          SearchPanel(
            selectedType: _type,
            onQueryChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            onTypeChanged: (value) {
              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<User?>(
            stream: authService.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: GuestLoginBanner(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          FeaturedGrid(query: _query, type: _type),
        ],
      ),
    );
  }
}

class SearchPanel extends StatelessWidget {
  const SearchPanel({
    required this.selectedType,
    required this.onQueryChanged,
    required this.onTypeChanged,
    super.key,
  });

  final CatalogItemType? selectedType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CatalogItemType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GothicIvyContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: t(context, 'searchHint'),
                hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14, fontFamily: 'Outfit'),
                prefixIcon: _buildNeonIcon(context, Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showCatalogFilterSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEC008C).withOpacity(isDark ? 0.5 : 0.25),
                  width: 1.2,
                ),
                color: isDark ? const Color(0xFF160E22) : Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNeonIcon(context, Icons.tune_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    selectedType == null ? (tr ? 'Hepsi' : 'All') : _catalogTypeLabel(context, selectedType!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFFEC008C),
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

  void _showCatalogFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        return GothicIvyContainer(
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr ? 'Katalog Filtrele' : 'Filter Catalog',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
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
                    isSelected: selectedType == null,
                    label: t(context, 'all'),
                    onTap: () {
                      onTypeChanged(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final type in CatalogItemType.values)
                    _buildFilterChip(
                      context: context,
                      isSelected: selectedType == type,
                      label: _catalogTypeLabel(context, type),
                      onTap: () {
                        onTypeChanged(type);
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
}

class FeaturedGrid extends StatelessWidget {
  const FeaturedGrid({
    required this.query,
    required this.type,
    super.key,
  });

  final String query;
  final CatalogItemType? type;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CatalogEntry>>(
      valueListenable: catalogEntriesNotifier,
      builder: (context, entries, _) {
        final items = _filterCatalogEntries(entries, query, type);
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: t(context, 'noCatalogResults'),
            body: t(context, 'noCatalogResultsBody'),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const columns = 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, index) => CatalogCard(item: items[index]),
            );
          },
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  const CatalogCard({required this.item, super.key});

  final CatalogEntry item;

  @override
  Widget build(BuildContext context) {
    final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
    return Card(
      color: isPng ? Colors.transparent : null,
      elevation: isPng ? 0 : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catalog/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DollImage(
                imageUrl: item.primaryImageUrl,
                label: _entryName(context, item),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _entryName(context, item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _entrySubtitle(context, item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.1,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  ValueListenableBuilder<List<CollectionEntry>>(
                    valueListenable: collectionEntriesNotifier,
                    builder: (context, collectionEntries, _) {
                      final entry = collectionEntries.firstWhere(
                        (e) => e.itemId == item.id,
                        orElse: () => const CollectionEntry(
                          id: '',
                          userId: '',
                          itemId: '',
                          status: CollectionStatus.owned,
                          condition: CollectionCondition.complete,
                          quantity: 0,
                        ),
                      );

                      final isOwned = entry.quantity > 0 && entry.status == CollectionStatus.owned;
                      final isWanted = entry.quantity > 0 && entry.status == CollectionStatus.wanted;
                      final isTrade = entry.quantity > 0 && entry.status == CollectionStatus.trade;
                      final isSelling = entry.quantity > 0 && entry.status == CollectionStatus.selling;

                      return SizedBox(
                        height: 30,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _CardActionButton(
                                tooltip: t(context, 'owned'),
                                icon: Icons.check_rounded,
                                isActive: isOwned,
                                activeColor: DollDexTheme.teal,
                                onPressed: () => _showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'want'),
                                icon: isWanted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                isActive: isWanted,
                                activeColor: DollDexTheme.berry,
                                onPressed: () => _showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'trade'),
                                icon: Icons.swap_horiz_rounded,
                                isActive: isTrade,
                                activeColor: Colors.deepPurpleAccent,
                                onPressed: () => _showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'selling'),
                                icon: Icons.sell_outlined,
                                isActive: isSelling,
                                activeColor: DollDexTheme.amber,
                                onPressed: () => _showCollectionSheet(context, item),
                              ),
                              const SizedBox(width: 4),
                              _CardActionButton(
                                tooltip: t(context, 'report'),
                                icon: Icons.flag_outlined,
                                isNeonFlag: true,
                                onPressed: () => _showReportSheet(
                                  context,
                                  ReportTargetType.catalogEntry,
                                  item.id,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.isNeonFlag = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;
  final bool isNeonFlag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = activeColor ?? const Color(0xFFEC008C);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? finalColor.withOpacity(0.25)
                : (isDark ? const Color(0xFF160E22).withOpacity(0.5) : const Color(0xFFFAF2FF)),
            border: Border.all(
              color: isActive
                  ? finalColor
                  : (isNeonFlag
                      ? const Color(0xFFEC008C).withOpacity(isDark ? 0.6 : 0.8)
                      : finalColor.withOpacity(isDark ? 0.35 : 0.6)),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: finalColor.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: SafeShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: isActive
                      ? [finalColor, Colors.white]
                      : [
                          finalColor.withOpacity(isDark ? 0.5 : 0.85),
                          (activeColor ?? const Color(0xFF00FFCC)).withOpacity(isDark ? 0.5 : 0.85)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Icon(
                icon,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DollImage extends StatelessWidget {
  const DollImage({
    required this.imageUrl,
    required this.label,
    this.fit,
    super.key,
  });

  final String imageUrl;
  final String label;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _ImagePlaceholder(label: label);
    }

    final isPng = imageUrl.toLowerCase().contains('.png');
    return Container(
      color: isPng ? Colors.transparent : null,
      child: getWebImage(
        imageUrl: imageUrl,
        label: label,
        fit: fit ?? (isPng ? BoxFit.contain : BoxFit.cover),
      ),
    );
  }
}

class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    required this.item,
    super.key,
  });

  final CatalogEntry item;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  final _commentController = TextEditingController();
  StreamSubscription<List<AppComment>>? _commentsSubscription;

  @override
  void initState() {
    super.initState();
    _watchComments();
  }

  @override
  void didUpdateWidget(CatalogDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _watchComments();
    }
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _watchComments() {
    _commentsSubscription?.cancel();
    _commentsSubscription = commentRepository
        .watchForTarget(targetType: 'catalogEntry', targetId: widget.item.id)
        .listen((comments) {
      commentsNotifier.value = {
        ...commentsNotifier.value,
        widget.item.id: comments,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return PageShell(
      title: _entryName(context, item),
      subtitle: _entrySubtitle(context, item),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          final isPng = item.primaryImageUrl.toLowerCase().contains('.png');
          final imagePanel = Card(
            color: isPng ? Colors.transparent : null,
            elevation: isPng ? 0 : null,
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: item.imageUrls.length > 1
                  ? _GothicImageSlider(
                      imageUrls: item.imageUrls,
                      label: _entryName(context, item),
                    )
                  : GestureDetector(
                      onTap: () => _showPhotoGalleryDialog(
                        context,
                        item.imageUrls.isNotEmpty ? item.imageUrls : [item.primaryImageUrl],
                        0,
                      ),
                      child: DollImage(
                        imageUrl: item.primaryImageUrl,
                        label: _entryName(context, item),
                      ),
                    ),
            ),
          );
          final infoPanel = _CatalogInfoPanel(
            item: item,
            onAdd: () => _showCollectionSheet(context, item),
            onReport: () => _showReportSheet(
              context,
              ReportTargetType.catalogEntry,
              item.id,
            ),
          );

          if (wide) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: imagePanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: infoPanel),
                  ],
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<Map<String, List<AppComment>>>(
                  valueListenable: commentsNotifier,
                  builder: (context, commentsByTarget, _) {
                    return _CommentsPanel(
                      controller: _commentController,
                      comments:
                          commentsByTarget[item.id] ?? const <AppComment>[],
                      onSubmit: _addComment,
                    );
                  },
                ),
              ],
            );
          }

          return Column(
            children: [
              imagePanel,
              const SizedBox(height: 16),
              infoPanel,
              const SizedBox(height: 16),
              ValueListenableBuilder<Map<String, List<AppComment>>>(
                valueListenable: commentsNotifier,
                builder: (context, commentsByTarget, _) {
                  return _CommentsPanel(
                    controller: _commentController,
                    comments: commentsByTarget[item.id] ?? const <AppComment>[],
                    onSubmit: _addComment,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final itemId = widget.item.id;
    final user = authService.currentUser;
    String senderUsername = 'Collector';
    String senderAvatarId = '';
    String senderFrameColor = '';
    if (user != null) {
      senderUsername = user.displayName ?? 'Collector';
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        final customUsername = data?['username'] as String? ?? '';
        if (customUsername.isNotEmpty) {
          senderUsername = '@$customUsername';
        }
        senderAvatarId = data?['avatarId'] as String? ?? '';
        senderFrameColor = data?['avatarFrameColor'] as String? ?? '';
      } catch (_) {}
    }

    final comment = AppComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      targetType: 'catalogEntry',
      targetId: itemId,
      userId: user?.uid ?? 'local-user',
      text: text,
      senderUsername: senderUsername,
      senderAvatarId: senderAvatarId,
      senderFrameColor: senderFrameColor,
    );
    final current = commentsNotifier.value[itemId] ?? const <AppComment>[];
    commentsNotifier.value = {
      ...commentsNotifier.value,
      itemId: [comment, ...current],
    };
    commentRepository.add(comment).catchError((_) {});
    _addAppNotification(
      '${_entryName(context, widget.item)}: ${t(context, 'commentAdded')}',
    );
    _commentController.clear();
  }
}

class _CatalogInfoPanel extends StatelessWidget {
  const _CatalogInfoPanel({
    required this.item,
    required this.onAdd,
    required this.onReport,
  });

  final CatalogEntry item;
  final VoidCallback onAdd;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(_catalogTypeLabel(context, item.type))),
                if (item.year != null) Chip(label: Text('${item.year}')),
                for (final tag in item.tags) Chip(label: Text(tag)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.description.isEmpty
                  ? t(context, 'wikiPlaceholder')
                  : _entryDescription(context, item),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(t(context, 'addToCollection')),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: t(context, 'report'),
                  child: _buildGothicNeonIconButton(
                    context: context,
                    icon: Icons.flag_outlined,
                    onPressed: onReport,
                    size: 20,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.controller,
    required this.comments,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final List<AppComment> comments;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'comments'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: t(context, 'commentHint'),
                hintStyle: const TextStyle(fontFamily: 'Outfit'),
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_outlined),
              label: Text(t(context, 'postComment')),
            ),
            const SizedBox(height: 14),
            for (final comment in comments)
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
                    leading: _buildAvatarHelper(
                      comment.senderAvatarId,
                      comment.senderFrameColor,
                      size: 38,
                    ),
                    title: Text(
                      comment.senderUsername.isNotEmpty
                          ? comment.senderUsername
                          : 'Collector',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      comment.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      tooltip: t(context, 'reportComment'),
                      onPressed: () => _showReportSheet(
                        context,
                        ReportTargetType.comment,
                        comment.id,
                      ),
                      icon: _buildNeonFlagIcon(context, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E152C) : DollDexTheme.mist,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGothicNeonIconButton(
            context: context,
            icon: Icons.image_outlined,
            size: 36,
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  CollectionStatus? _filter;
  CollectionCondition? _conditionFilter;
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
    final confirmed = await _showGothicConfirmDialog(
      context,
      title: tr ? 'Koleksiyondan Sil' : 'Delete from Collection',
      content: tr
          ? '${_selectedEntryIds.length} adet bebeği koleksiyonunuzdan silmek istediğinize emin misiniz?'
          : 'Are you sure you want to delete ${_selectedEntryIds.length} dolls from your collection?',
      confirmText: tr ? 'Toplu Sil' : 'Bulk Delete',
    );

    if (confirmed == true) {
      final userId = authService.currentUser?.uid;
      if (userId != null) {
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
        setState(() {
          _selectedEntryIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr ? 'Seçilenler silindi.' : 'Selected items deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return PageShell(
      title: t(context, 'collection'),
      subtitle: t(context, 'collectionSubtitle'),
      child: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;
          if (user == null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                _buildGothicNeonIconButton(
                  context: context,
                  icon: Icons.inventory_2_outlined,
                  size: 36,
                  padding: const EdgeInsets.all(12),
                  activeColor: DollDexTheme.teal,
                ),
                const SizedBox(height: 16),
                Text(
                  tr ? 'Koleksiyonunu Takip Et' : 'Track Your Collection',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr
                      ? 'Kendi koleksiyon rafını oluşturmak ve bebekleri bulutla senkronize etmek için giriş yapmalısın.'
                      : 'You must sign in to create your own collection shelf and sync dolls with the cloud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                const GuestLoginBanner(),
              ],
            );
          }

          return ValueListenableBuilder<List<CollectionEntry>>(
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
              final filteredEntries = _query.isEmpty
                  ? condEntries
                  : condEntries.where((entry) {
                      final item = _findCatalogEntry(entry.itemId);
                      final name = _entryName(context, item).toLowerCase();
                      return name.contains(_query.toLowerCase());
                    }).toList(growable: false);

              return Column(
                children: [
                  StatRow(entries: entries),
                  const SizedBox(height: 16),
                  if (_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF160E22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEC008C), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text(
                            tr 
                                ? '${_selectedEntryIds.length} Seçildi' 
                                : '${_selectedEntryIds.length} Selected',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _selectAll(filteredEntries),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(
                              _selectedEntryIds.length == filteredEntries.length 
                                  ? (tr ? 'Seçimi Kaldır' : 'Deselect All')
                                  : (tr ? 'Hepsini Seç' : 'Select All'),
                              style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: _deleteSelectedEntries,
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: tr ? 'Toplu Sil' : 'Bulk Delete',
                          ),
                          IconButton(
                            onPressed: _cancelSelection,
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            tooltip: tr ? 'Vazgeç' : 'Cancel',
                          ),
                        ],
                      ),
                    )
                  else
                    CollectionSearchPanel(
                      selectedStatus: _filter,
                      selectedCondition: _conditionFilter,
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
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onConditionChanged,
    super.key,
  });

  final CollectionStatus? selectedStatus;
  final CollectionCondition? selectedCondition;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CollectionStatus?> onStatusChanged;
  final ValueChanged<CollectionCondition?> onConditionChanged;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GothicIvyContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: tr ? 'Koleksiyonda ara...' : 'Search in shelf...',
                hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14, fontFamily: 'Outfit'),
                prefixIcon: _buildNeonIcon(context, Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showCollectionFilterSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEC008C).withOpacity(isDark ? 0.5 : 0.25),
                  width: 1.2,
                ),
                color: isDark ? const Color(0xFF160E22) : Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNeonIcon(context, Icons.tune_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    selectedStatus == null && selectedCondition == null
                        ? (tr ? 'Filtre' : 'Filter')
                        : (tr ? 'Aktif' : 'Active'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFFEC008C),
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
      backgroundColor: isDark ? const Color(0xFF0E0818) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: const Color(0xFFEC008C).withOpacity(0.25), width: 1.0),
      ),
      builder: (context) {
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        return GothicIvyContainer(
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr ? 'Koleksiyon Filtrele' : 'Filter Collection',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr ? 'Koleksiyon Durumu' : 'Collection Status',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
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
                      label: _collectionStatusLabel(context, status),
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
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
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
                      label: _conditionLabel(context, condition),
                      onTap: () {
                        onConditionChanged(condition);
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
}

class StatRow extends StatelessWidget {
  const StatRow({required this.entries, super.key});

  final List<CollectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final owned = entries
        .where((entry) => entry.status == CollectionStatus.owned)
        .length;
    final wanted = entries
        .where((entry) => entry.status == CollectionStatus.wanted)
        .length;
    final trade = entries
        .where((entry) => entry.status == CollectionStatus.trade)
        .length;
    final selling = entries
        .where((entry) => entry.status == CollectionStatus.selling)
        .length;

    return Row(
      children: [
        Expanded(child: StatCard(label: t(context, 'owned'), value: '$owned')),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: t(context, 'wanted'), value: '$wanted')),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: t(context, 'trade'), value: '$trade')),
        const SizedBox(width: 8),
        Expanded(child: StatCard(label: t(context, 'selling'), value: '$selling')),
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
        const columns = 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.66,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelected = selectedIds.contains(entry.id);
            return CollectionGridCard(
              entry: entry,
              isSelected: isSelected,
              isSelectionMode: isSelectionMode,
              onTap: () {
                if (isSelectionMode) {
                  onToggleSelect(entry.id);
                } else {
                  context.push('/collection/entry/${entry.id}');
                }
              },
              onLongPress: () {
                onToggleSelect(entry.id);
              },
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
    final item = _findCatalogEntry(entry.itemId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPng = item.primaryImageUrl.toLowerCase().contains('.png');

    return Card(
      color: isPng ? Colors.transparent : null,
      elevation: isPng ? 0 : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFEC008C)
              : (isPng
                  ? Colors.transparent
                  : (isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA))),
          width: isSelected ? 3.0 : (isPng ? 0.0 : 1.5),
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DollImage(
                        imageUrl: item.primaryImageUrl,
                        label: _entryName(context, item),
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _entryName(context, item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              children: [
                                _buildStatusIcon(context, entry.status),
                                Text(
                                  _collectionStatusLabel(context, entry.status),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'x${entry.quantity}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
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
          ),
        ],
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
    return _buildGothicNeonIconButton(
      context: context,
      icon: icon,
      size: 10,
      padding: const EdgeInsets.all(3),
      activeColor: const Color(0xFF00FFCC),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DollDexTheme.teal,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: firebaseReadyNotifier,
          builder: (context, firebaseReady, _) {
            if (!firebaseReady) {
              return PageShell(
                title: t(context, 'profile'),
                subtitle: t(context, 'profileSubtitle'),
                child: SignInPanel(
                  onGooglePressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
                    );
                  },
                ),
              );
            }

            return StreamBuilder<User?>(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return PageShell(
                    title: t(context, 'profile'),
                    subtitle: t(context, 'profileSubtitle'),
                    child: SignInPanel(
                      isLoading: _isSigningIn,
                      onGooglePressed: _handleGoogleSignIn,
                    ),
                  );
                }

                final user = snapshot.data;
                if (user == null) {
                  return PageShell(
                    title: t(context, 'profile'),
                    subtitle: t(context, 'profileSubtitle'),
                    child: SignInPanel(
                      isLoading: _isSigningIn,
                      onGooglePressed: _handleGoogleSignIn,
                    ),
                  );
                }

                return StreamBuilder<ProfileSetupStatus>(
                  stream: profileSetupRepository.watch(user.uid),
                  builder: (context, profileSetupSnap) {
                    final setupStatus = profileSetupSnap.data;
                    final avatarId = setupStatus?.avatarId ?? '';
                    final frameColor = setupStatus?.avatarFrameColor ?? '';

                    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Cover Photo Stack
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildCoverPhoto(context, setupStatus?.coverId, isPro: setupStatus?.isPro == true),
                            Positioned(
                              top: 80,
                              left: 16,
                              child: InkWell(
                                onTap: () => _showAvatarStudioModal(context, user.uid),
                                borderRadius: BorderRadius.circular(38),
                                child: _buildAvatarHelper(avatarId, frameColor, size: 76),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 45),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              AccountSummaryCard(
                                displayName: user.displayName,
                                email: user.email,
                                onSignOut: _handleSignOut,
                                avatarId: avatarId,
                                frameColor: frameColor,
                              ),
                              const SizedBox(height: 8),
                              // Connections stats row
                              StreamBuilder<List<AppUser>>(
                                stream: socialRepository.watchFriendsList(user.uid),
                                builder: (context, friendsSnap) {
                                  final friendsCount = friendsSnap.data?.length ?? 0;
                                  return StreamBuilder<List<AppUser>>(
                                    stream: socialRepository.watchFollowingList(user.uid),
                                    builder: (context, followingSnap) {
                                      final followingCount = followingSnap.data?.length ?? 0;
                                      return StreamBuilder<List<AppUser>>(
                                        stream: socialRepository.watchFollowersList(user.uid),
                                        builder: (context, followersSnap) {
                                          final followersCount = followersSnap.data?.length ?? 0;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                                            child: InkWell(
                                              onTap: () => _showConnectionsModal(context, user.uid),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.4), width: 1.2),
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFF171026)
                                                      : const Color(0xFFFAF2FF),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Arkadaş' : 'Friends',
                                                      value: friendsCount.toString(),
                                                    ),
                                                    Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Takip' : 'Following',
                                                      value: followingCount.toString(),
                                                    ),
                                                    Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                                    _buildStatItem(
                                                      context,
                                                      label: tr ? 'Takipçi' : 'Followers',
                                                      value: followersCount.toString(),
                                                    ),
                                                  ],
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
                              const SizedBox(height: 12),
                              ProfileSetupCard(userId: user.uid),
                              const SizedBox(height: 16),
                              const ProfileStatsCard(),
                              const SizedBox(height: 16),
                              const ProfileShowcaseCard(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLanguageScope.languageOf(context) == AppLanguage.tr
                      ? '${localEntries.length} parça hesabınıza aktarıldı!'
                      : '${localEntries.length} items migrated to your account!',
                ),
              ),
            );
          }
        }
      }
      await _loadCollectionForCurrentUser();
      await _loadReports();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInSuccess'))),
      );
    } on AuthCancelledException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInCancelled'))),
      );
    } on StateError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'signInFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await authService.signOut();
      collectionEntriesNotifier.value = <CollectionEntry>[];
      reportsNotifier.value = <UserReport>[];
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'signOutFailed')} $error')),
      );
    }
  }
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

class AccountSummaryCard extends StatelessWidget {
  const AccountSummaryCard({
    required this.displayName,
    required this.email,
    required this.onSignOut,
    this.avatarId = '',
    this.frameColor = '',
    super.key,
  });

  final String? displayName;
  final String? email;
  final Future<void> Function() onSignOut;
  final String avatarId;
  final String frameColor;

  @override
  Widget build(BuildContext context) {
    final title = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : t(context, 'collectorAccount');
    final subtitle = email?.trim().isNotEmpty == true
        ? email!.trim()
        : t(context, 'signedIn');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatarHelper(avatarId, frameColor, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Ayarlar' : 'Settings',
              child: _buildGothicNeonIconButton(
                context: context,
                icon: Icons.settings_outlined,
                onPressed: () => context.push('/settings'),
                size: 20,
                padding: const EdgeInsets.all(6),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: t(context, 'signOut'),
              child: _buildGothicNeonIconButton(
                context: context,
                icon: Icons.logout_rounded,
                onPressed: onSignOut,
                size: 20,
                padding: const EdgeInsets.all(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSetupCard extends StatefulWidget {
  const ProfileSetupCard({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<ProfileSetupCard> createState() => _ProfileSetupCardState();
}

class _ProfileSetupCardState extends State<ProfileSetupCard> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _birthYearController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(widget.userId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status?.isComplete == true) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${t(context, 'username')}: @${status!.username}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (status != null && _usernameController.text.isEmpty) {
          _usernameController.text = status.username;
        }
        if (status?.birthYear != null && _birthYearController.text.isEmpty) {
          _birthYearController.text = '${status!.birthYear}';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'completeProfileRequired'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(t(context, 'completeProfileBody')),
                  const SizedBox(height: 8),
                  Text(
                    t(context, 'usernameChangeWarning'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    maxLength: 15,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      labelText: t(context, 'username'),
                      prefixText: '@',
                      helperText: t(context, 'usernameRules'),
                    ),
                    validator: (value) {
                      final username =
                          ProfileSetupRepository.normalizeUsername(value ?? '');
                      if (!ProfileSetupRepository.isValidUsername(username)) {
                        return t(context, 'usernameInvalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _birthYearController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      labelText: t(context, 'birthYear'),
                      helperText: t(context, 'ageRequirement'),
                    ),
                    validator: (value) {
                      final birthYear = int.tryParse(value ?? '');
                      final currentYear = DateTime.now().year;
                      if (birthYear == null ||
                          birthYear < 1900 ||
                          birthYear > currentYear) {
                        return t(context, 'birthYearInvalid');
                      }
                      if (ProfileSetupRepository.ageFromBirthYear(birthYear) <
                          ProfileSetupRepository.minAge) {
                        return t(context, 'ageTooYoung');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(t(context, 'saveProfile')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      await profileSetupRepository.saveRequiredProfile(
        userId: widget.userId,
        username: _usernameController.text,
        birthYear: int.parse(_birthYearController.text),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'profileSaved'))),
      );
    } on UsernameTakenException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'usernameTaken'))),
      );
    } on UsernameChangeLockedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'usernameChangeLocked'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'profileSaveFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}



class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.avatarId,
    required this.selected,
    required this.frameColor,
    required this.onTap,
  });

  final String avatarId;
  final bool selected;
  final String frameColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: _buildAvatarHelper(
        avatarId,
        selected ? frameColor : '',
        size: 56,
      ),
    );
  }
}

class GuestLoginBanner extends StatefulWidget {
  const GuestLoginBanner({super.key});

  @override
  State<GuestLoginBanner> createState() => _GuestLoginBannerState();
}

class _GuestLoginBannerState extends State<GuestLoginBanner> {
  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.stars_rounded, color: DollDexTheme.teal, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr ? 'Koleksiyonunu Bulutta Sakla!' : 'Save Your Collection in the Cloud!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr
                            ? 'Google ile giriş yaparak bebeklerini takip et, yorum yaz ve sergile!'
                            : 'Sign in with Google to track your dolls, post comments, and showcase your shelf!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC008C), Color(0xFF7B2CBF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC008C).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                label: Text(
                  tr ? 'Google ile Hızlı Giriş Yap' : 'Quick Sign In with Google',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontFamily: 'Cinzel',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CollectionEntry>>(
      valueListenable: collectionEntriesNotifier,
      builder: (context, collectionEntries, _) {
        return ValueListenableBuilder<List<CatalogEntry>>(
          valueListenable: catalogEntriesNotifier,
          builder: (context, catalogEntries, _) {
            return ValueListenableBuilder<Map<String, List<AppComment>>>(
              valueListenable: commentsNotifier,
              builder: (context, commentsByTarget, _) {
                final commentCount = commentsByTarget.values.fold<int>(
                  0,
                  (total, comments) => total + comments.length,
                );

                return ValueListenableBuilder<List<UserReport>>(
                  valueListenable: reportsNotifier,
                  builder: (context, reports, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(context, 'profileStats'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.inventory_2_outlined,
                                    label: t(context, 'collection'),
                                    value: '${collectionEntries.length}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.search_rounded,
                                    label: t(context, 'catalog'),
                                    value: '${catalogEntries.length}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: t(context, 'comments'),
                                    value: '$commentCount',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GothicStatButton(
                                    icon: Icons.flag_outlined,
                                    label: t(context, 'report'),
                                    value: '${reports.length}',
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
              },
            );
          },
        );
      },
    );
  }
}

class GothicStatButton extends StatelessWidget {
  const GothicStatButton({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Yarı saydam lila arka plan ve neon mor border
    final bgCol = isDark
        ? const Color(0xFFD6C3F7).withOpacity(0.12)
        : const Color(0xFFD6C3F7).withOpacity(0.25);
    final borderCol = const Color(0xFF8338EC).withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderCol,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8338EC).withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ayarlar çarkı ve çıkış butonu ile birebir aynı simge tasarımı
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF2FF),
              border: Border.all(
                color: const Color(0xFFEC008C).withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC008C).withOpacity(0.15),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: _buildNeonIcon(context, icon, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF8338EC),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.0,
              color: isDark ? Colors.white70 : const Color(0xFF6B5885),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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

class ProfileShowcaseCard extends StatelessWidget {
  const ProfileShowcaseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CollectionEntry>>(
      valueListenable: collectionEntriesNotifier,
      builder: (context, entries, _) {
        if (entries.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'profileShowcaseTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(t(context, 'profileShowcaseEmpty')),
                ],
              ),
            ),
          );
        }

        final owned = entries.where((e) => e.status == CollectionStatus.owned).toList();
        final wanted = entries.where((e) => e.status == CollectionStatus.wanted).toList();
        final trade = entries.where((e) => e.status == CollectionStatus.trade).toList();
        final selling = entries.where((e) => e.status == CollectionStatus.selling).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTabController(
              length: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'profileShowcaseTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    tabs: [
                      Tab(text: t(context, 'owned')),
                      Tab(text: t(context, 'wanted')),
                      Tab(text: t(context, 'trade')),
                      Tab(text: t(context, 'selling')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        CollectionCategoryTab(entries: owned),
                        CollectionCategoryTab(entries: wanted),
                        CollectionCategoryTab(entries: trade),
                        CollectionCategoryTab(entries: selling),
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
}

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
              _buildNeonIcon(context, icon, size: 24),
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
                  onTap: () => _showAvatarStudioModal(context, user.uid),
                ),
                const Divider(color: Color(0xFF2C1F45), height: 16, thickness: 0.8),
                buildGothicRow(
                  context: context,
                  icon: Icons.alternate_email_rounded,
                  title: tr ? 'Kullanıcı Adı Değiştir' : 'Change Username',
                  subtitle: tr ? 'Benzersiz @kullanıcı_adı belirle' : 'Set your unique @username',
                  onTap: () => _showChangeUsernameDialog(context, user.uid),
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
                  onTap: () => _showReportsModal(context, user.uid),
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
}

void _showAvatarStudioModal(BuildContext context, String userId) {
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
                    t(context, 'avatarStudio'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: DollDexTheme.teal,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(t(context, 'avatarStudioBody')),
                  const SizedBox(height: 16),
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
                      return Opacity(
                        opacity: isPro ? 1.0 : 0.4,
                        child: _AvatarOption(
                          avatarId: avatarId,
                          selected: isSelected,
                          frameColor: selectedFrame,
                          onTap: isPro
                              ? () {
                                  profileSetupRepository.saveAvatar(
                                    userId: userId,
                                    avatarId: avatarId,
                                    avatarFrameColor: selectedFrame,
                                  );
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        tr
                                            ? 'Avatarlar sadece Pro üyeler içindir!'
                                            : 'Avatars are for Pro members only!',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      );
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
                        InkWell(
                          onTap: isPro
                              ? () {
                                  profileSetupRepository.saveAvatar(
                                    userId: userId,
                                    avatarId: selectedAvatar,
                                    avatarFrameColor: frame,
                                  );
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(t(context, 'proFramesLocked'))),
                                  );
                                },
                          child: Opacity(
                            opacity: isPro ? 1.0 : 0.4,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedFrame == frame
                                      ? const Color(0xFFEC008C)
                                      : Colors.grey.shade800,
                                  width: selectedFrame == frame ? 2.5 : 1.5,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  GothicFrameWidget(frameType: frame, size: 36),
                                  if (selectedFrame == frame)
                                    const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFFEC008C),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!isPro) ...[
                    const SizedBox(height: 12),
                    Text(
                      t(context, 'proFramesLocked'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    tr ? 'Gotik Kapak Fotoğrafları' : 'Gothic Cover Photos',
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
                        return InkWell(
                          onTap: isPro
                              ? () {
                                  profileSetupRepository.saveCover(
                                    userId: userId,
                                    coverId: coverId,
                                  );
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        tr
                                            ? 'Kapak fotoğrafları sadece Pro üyeler içindir!'
                                            : 'Cover photos are for Pro members only!',
                                      ),
                                    ),
                                  );
                                },
                          child: Opacity(
                            opacity: isPro ? 1.0 : 0.4,
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
                        );
                      },
                    ),
                  ),
                  if (!isPro) ...[
                    const SizedBox(height: 12),
                    Text(
                      tr
                          ? 'Kapak fotoğrafları Pro kullanıcılar için açıktır.'
                          : 'Cover photos are available for Pro users.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
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

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: t(context, 'deleteAccount'),
      subtitle: t(context, 'legalSubtitle'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, 'deleteBody')),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Outfit'),
                decoration: InputDecoration(
                  labelText: t(context, 'deleteReason'),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t(context, 'sendDeleteRequest')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'signInNeedsFirebase'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await accountDeletionRepository.requestDeletion(
        userId: user.uid,
        email: user.email ?? '',
        reason: _reasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _reasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'deleteRequestSaved'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'deleteRequestFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class SocialScreen extends StatefulWidget {
  const SocialScreen({this.chatUserId, super.key});

  final String? chatUserId;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.chatUserId != null && widget.chatUserId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDirectChatWithUser(context, widget.chatUserId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t(context, 'socialSignInRequired')),
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
            Text(
              t(context, 'social'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF160E24) : const Color(0xFFFAF6FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF00FFCC).withOpacity(0.25)
                      : const Color(0xFFEC008C).withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C)).withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNeonIcon(context, Icons.info_outline_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t(context, 'socialSubtitle'),
                      style: TextStyle(
                        color: isDark ? const Color(0xFFC4B2D9) : const Color(0xFF6B5885),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PendingRequestsCard(userId: user.uid),
            const SizedBox(height: 12),
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

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t(context, 'socialSignInRequired')),
          ),
        ),
      );
    }

    return const SafeArea(
      child: _DirectMessagesModalContent(showDragHandle: false),
    );
  }
}

class _GlobalChatCard extends StatefulWidget {
  const _GlobalChatCard({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<_GlobalChatCard> createState() => _GlobalChatCardState();
}

class _GlobalChatCardState extends State<_GlobalChatCard> {
  final _globalMessageController = TextEditingController();
  final _searchController = TextEditingController();
  final _globalMessageFocusNode = FocusNode();
  List<AppUser> _results = const <AppUser>[];
  bool _isSearching = false;
  bool _showSearchInput = false;

  @override
  void dispose() {
    _globalMessageController.dispose();
    _searchController.dispose();
    _globalMessageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text;
    if (query.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final users = await socialRepository.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = users
            .where((user) => user.id != widget.userId)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'socialSearchFailed')} $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    await socialRepository.sendFriendRequest(
      fromUserId: widget.userId,
      toUserId: targetUserId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'friendRequestSent'))),
    );
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
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _showSearchInput ? 180.0 : 0.0,
                  height: 36,
                  curve: Curves.easeInOut,
                  child: _showSearchInput
                      ? TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _searchUsers(),
                          style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Colors.white),
                          decoration: InputDecoration(
                            hintText: t(context, 'searchUsername'),
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFFEC008C), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                            ),
                            suffixIcon: _isSearching
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC008C)),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _results = const [];
                                        _showSearchInput = false;
                                      });
                                    },
                                  ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (!_showSearchInput)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearchInput = true;
                      });
                    },
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF00FFCC), size: 20),
                    label: Text(
                      tr ? 'Kullanıcı Ara' : 'Search User',
                      style: const TextStyle(
                        color: Color(0xFF00FFCC),
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171026) : const Color(0xFFFAF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.3)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final target = _results[index];
                    return ListTile(
                      dense: true,
                      leading: _buildAvatarHelper(target.avatarId, target.avatarFrameColor, size: 28),
                      title: Text(
                        target.username.isEmpty ? target.displayName : '@${target.username}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF00FFCC)),
                            onPressed: () => _sendFriendRequest(target.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle_outlined, size: 18, color: Color(0xFFEC008C)),
                            onPressed: () => context.push('/users/${target.id}'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.userId;
                      return _buildGlobalMsgBubble(context, message, isMe);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _globalMessageController,
                    focusNode: _globalMessageFocusNode,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendGlobalMessage(),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: t(context, 'globalMessage'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC008C).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
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

  Widget _buildGlobalMsgBubble(BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => context.push('/users/${msg.senderId}'),
              child: _buildAvatarHelper(msg.senderAvatarId, msg.senderFrameColor, size: 32),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF2C1F45), const Color(0xFF1C1330)]
                              : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe) ...[
                      GestureDetector(
                        onTap: () => context.push('/users/${msg.senderId}'),
                        child: Text(
                          msg.senderUsername.isEmpty ? msg.senderId : '@${msg.senderUsername}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFF8338EC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(msg.createdAt),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 8.5,
                            color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
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
              onPressed: () => _showReportSheet(
                context,
                ReportTargetType.comment,
                msg.id,
              ),
              icon: _buildNeonFlagIcon(context, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _commentController = TextEditingController();
  late Future<List<CollectionEntry>> _collectionFuture;

  @override
  void initState() {
    super.initState();
    _collectionFuture = collectionRepository.listPublicForUser(widget.userId);
    _recordProfileVisit();
  }

  void _recordProfileVisit() async {
    final currentUserId = authService.currentUser?.uid;
    if (currentUserId == null || currentUserId == widget.userId) {
      return;
    }

    try {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final senderName = senderDoc.data()?['username'] as String? ?? authService.currentUser?.displayName ?? 'Collector';

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.userId,
        'type': 'follow',
        'title': AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Profil Ziyareti!' : 'Profile Visit!',
        'body': AppLanguageScope.languageOf(context) == AppLanguage.tr
            ? '@$senderName profilini ziyaret etti!'
            : '@$senderName visited your profile!',
        'isRead': false,
        'deepLink': '/social',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ProfileSetupStatus>(
          stream: profileSetupRepository.watch(widget.userId),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            final avatarId = profile?.avatarId ?? '';
            final frameColor = profile?.avatarFrameColor ?? '';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // Cover Photo
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildCoverPhoto(context, profile?.coverId, isPro: profile?.isPro == true),
                    Positioned(
                      top: 80,
                      left: 16,
                      child: _buildAvatarHelper(avatarId, frameColor, size: 76),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.4),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => _showPublicProfileActionsMenu(context, widget.userId),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.username.isNotEmpty == true ? '@${profile!.username}' : 'Collector',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (authService.currentUser != null && authService.currentUser!.uid != widget.userId)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StreamBuilder<bool>(
                                  stream: socialRepository.watchIsFriend(authService.currentUser!.uid, widget.userId),
                                  builder: (context, friendSnap) {
                                    final isFriend = friendSnap.data == true;
                                    if (!isFriend) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () {
                                          _openDirectChatWithUser(context, widget.userId);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF00FFCC), Color(0xFF00B38F)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00FFCC).withOpacity(0.2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.chat_bubble_outline_rounded,
                                                size: 14,
                                                color: Colors.black87,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Mesaj' : 'Message',
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                StreamBuilder<bool>(
                                  stream: socialRepository.watchIsFollowing(authService.currentUser!.uid, widget.userId),
                                  builder: (context, followSnap) {
                                    final isFollowing = followSnap.data == true;
                                    return InkWell(
                                      onTap: () async {
                                        final currentUid = authService.currentUser!.uid;
                                        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                        final confirmed = await _showGothicConfirmDialog(
                                          context,
                                          title: isFollowing ? (tr ? 'Takibi Bırak' : 'Unfollow') : (tr ? 'Takip Et' : 'Follow'),
                                          content: isFollowing
                                              ? (tr ? 'Bu kullanıcıyı takip etmeyi bırakmak istediğinize emin misiniz?' : 'Are you sure you want to stop following this user?')
                                              : (tr ? 'Bu kullanıcıyı takip etmek istediğinize emin misiniz?' : 'Are you sure you want to follow this user?'),
                                        );
                                        if (!confirmed) return;

                                        if (isFollowing) {
                                          await socialRepository.unfollowUser(
                                            currentUserId: currentUid,
                                            targetUserId: widget.userId,
                                          );
                                        } else {
                                          await socialRepository.followUser(
                                            currentUserId: currentUid,
                                            targetUserId: widget.userId,
                                          );
                                          try {
                                            final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                                            final senderName = senderDoc.data()?['username'] as String? ?? authService.currentUser?.displayName ?? 'Collector';
                                            await FirebaseFirestore.instance.collection('notifications').add({
                                              'userId': widget.userId,
                                              'type': 'follow',
                                              'title': AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Yeni Takipçi!' : 'New Follower!',
                                              'body': AppLanguageScope.languageOf(context) == AppLanguage.tr
                                                  ? '@$senderName seni takip etmeye başladı!'
                                                  : '@$senderName started following you!',
                                              'isRead': false,
                                              'deepLink': '/profile',
                                              'createdAt': FieldValue.serverTimestamp(),
                                            });
                                          } catch (_) {}
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: LinearGradient(
                                            colors: isFollowing
                                                ? [const Color(0xFF2C1F45), const Color(0xFF171026)]
                                                : [const Color(0xFFEC008C), const Color(0xFF8338EC)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFEC008C),
                                            width: 1.5,
                                          ),
                                          boxShadow: isFollowing
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: const Color(0xFFEC008C).withOpacity(0.3),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isFollowing
                                                  ? (AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Takibi Bırak' : 'Unfollow')
                                                  : (AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Takip Et' : 'Follow'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Connections stats row for public profile
                      StreamBuilder<List<AppUser>>(
                        stream: socialRepository.watchFriendsList(widget.userId),
                        builder: (context, friendsSnap) {
                          final friendsCount = friendsSnap.data?.length ?? 0;
                          return StreamBuilder<List<AppUser>>(
                            stream: socialRepository.watchFollowingList(widget.userId),
                            builder: (context, followingSnap) {
                              final followingCount = followingSnap.data?.length ?? 0;
                              return StreamBuilder<List<AppUser>>(
                                stream: socialRepository.watchFollowersList(widget.userId),
                                builder: (context, followersSnap) {
                                  final followersCount = followersSnap.data?.length ?? 0;
                                  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                                    child: InkWell(
                                      onTap: () => _showConnectionsModal(context, widget.userId),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFEC008C).withOpacity(0.4), width: 1.2),
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF171026)
                                              : const Color(0xFFFAF2FF),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Arkadaş' : 'Friends',
                                              value: friendsCount.toString(),
                                            ),
                                            Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Takip' : 'Following',
                                              value: followingCount.toString(),
                                            ),
                                            Container(width: 1.2, height: 24, color: const Color(0xFFEC008C).withOpacity(0.4)),
                                            _buildStatItem(
                                              context,
                                              label: tr ? 'Takipçi' : 'Followers',
                                              value: followersCount.toString(),
                                            ),
                                          ],
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
                      const SizedBox(height: 12),
                      FutureBuilder<List<CollectionEntry>>(
                        future: _collectionFuture,
                        builder: (context, snapshot) {
                          final entries = snapshot.data ?? const <CollectionEntry>[];
                          if (entries.isEmpty) {
                            return EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: t(context, 'publicCollectionEmpty'),
                              body: t(context, 'publicCollectionEmptyBody'),
                            );
                          }

                          final owned = entries.where((e) => e.status == CollectionStatus.owned).toList();
                          final wanted = entries.where((e) => e.status == CollectionStatus.wanted).toList();
                          final trade = entries.where((e) => e.status == CollectionStatus.trade).toList();
                          final selling = entries.where((e) => e.status == CollectionStatus.selling).toList();

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: DefaultTabController(
                                length: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t(context, 'publicCollection'),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TabBar(
                                      isScrollable: true,
                                      tabAlignment: TabAlignment.start,
                                      indicatorColor: Theme.of(context).colorScheme.primary,
                                      labelColor: Theme.of(context).colorScheme.primary,
                                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      tabs: [
                                        Tab(text: t(context, 'owned')),
                                        Tab(text: t(context, 'wanted')),
                                        Tab(text: t(context, 'trade')),
                                        Tab(text: t(context, 'selling')),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 320,
                                      child: TabBarView(
                                        children: [
                                          CollectionCategoryTab(entries: owned),
                                          CollectionCategoryTab(entries: wanted),
                                          CollectionCategoryTab(entries: trade),
                                          CollectionCategoryTab(entries: selling),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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

class LegalScreen extends StatelessWidget {
  const LegalScreen({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: title,
      subtitle: t(context, 'legalSubtitle'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            body,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _activeTab = 0; // 0: Bildirimler, 1: Duyurular

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> list, {
    required bool canDelete,
    required String userId,
    required bool isTr,
  }) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            isTr ? 'Bu kategoride bildirim bulunmuyor.' : 'No notifications in this category.',
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white54),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final notification = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Dismissible(
            key: Key('notification-${notification.id}-${notification.isRead}'),
            direction: canDelete ? DismissDirection.horizontal : DismissDirection.startToEnd,
            background: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF00FFCC), size: 18),
            ),
            secondaryBackground: canDelete
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC008C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEC008C), size: 18),
                  )
                : null,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await notificationRepository.markRead(notification.id);
                return false;
              } else if (direction == DismissDirection.endToStart && canDelete) {
                await notificationRepository.delete(notification.id);
                return true;
              }
              return false;
            },
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: notification.isRead
                      ? Colors.transparent
                      : (isDark
                          ? const Color(0xFFEC008C).withOpacity(0.5)
                          : const Color(0xFFEC008C).withOpacity(0.25)),
                  width: 1,
                ),
              ),
              color: isDark
                  ? (notification.isRead ? const Color(0xFF0F0918) : const Color(0xFF170D26))
                  : (notification.isRead ? const Color(0xFFF9F6FC) : const Color(0xFFF0E6F5)),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                onTap: () async {
                  final route = notification.deepLink;
                  if (!notification.isRead) {
                    notificationRepository.markRead(notification.id);
                  }
                  if (route.isNotEmpty && context.mounted) {
                    context.push(route);
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: notification.isRead
                        ? Colors.grey.withOpacity(0.1)
                        : const Color(0xFFEC008C).withOpacity(0.1),
                  ),
                  child: Icon(
                    _notificationTypeIcon(notification.type),
                    color: notification.isRead ? Colors.grey : const Color(0xFFEC008C),
                    size: 16,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    color: isDark
                        ? (notification.isRead ? const Color(0xFFB5A7C5) : Colors.white)
                        : (notification.isRead ? const Color(0xFF6B5885) : Colors.black87),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? (notification.isRead ? const Color(0xFF8E7E9D) : const Color(0xFFC4B2D9))
                            : (notification.isRead ? const Color(0xFF8E7E9D) : const Color(0xFF6B5885)),
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatMessageTime(notification.createdAt!),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: notification.isRead
                    ? null
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00FFCC),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final userId = user?.uid ?? 'local-user';
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      title: tr ? 'Bildirimler' : 'Notifications',
      subtitle: tr ? 'Sosyal etkileşimler ve sistem duyuruları' : 'Social interactions and announcements',
      child: StreamBuilder<List<AppNotification>>(
        stream: notificationRepository.watchForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC008C)),
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          final announcements = notifications.where((n) => n.deepLink.startsWith('/announcement')).toList();
          final regularNotifications = notifications.where((n) => !n.deepLink.startsWith('/announcement')).toList();

          if (notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: t(context, 'noNotifications'),
              body: t(context, 'noNotificationsBody'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row with mark all read button and info text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF160E24) : const Color(0xFFFAF6FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF00FFCC).withOpacity(0.2)
                              : const Color(0xFFEC008C).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr
                                  ? 'Sola kaydır: Sil | Sağa kaydır: Oku'
                                  : 'Swipe left: Delete | Swipe right: Read',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFE5DDF2) : const Color(0xFF6B5885),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (userId != 'local-user') ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF00FFCC)),
                      label: Text(
                        tr ? 'Tümünü Oku' : 'Read All',
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        await notificationRepository.markAllRead(userId);
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Sekmeler
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: tr ? 'Bildirimler (${regularNotifications.length})' : 'Notifications (${regularNotifications.length})',
                      isActive: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: tr ? 'Duyurular (${announcements.length})' : 'Announcements (${announcements.length})',
                      isActive: _activeTab == 1,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_activeTab == 0)
                _buildNotificationsList(
                  context,
                  regularNotifications,
                  canDelete: true,
                  userId: userId,
                  isTr: tr,
                )
              else
                _buildNotificationsList(
                  context,
                  announcements,
                  canDelete: false,
                  userId: userId,
                  isTr: tr,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive
              ? const Color(0xFFEC008C).withOpacity(0.15)
              : (isDark ? const Color(0xFF160E22) : Colors.white),
          border: Border.all(
            color: isActive
                ? const Color(0xFFEC008C)
                : (isDark ? const Color(0xFF2C1F45) : const Color(0xFFEC008C).withOpacity(0.2)),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? (isDark ? Colors.white : const Color(0xFFEC008C))
                : (isDark ? Colors.white70 : const Color(0xFF6B5885)),
          ),
        ),
      ),
    );
  }
}

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
                    final confirmed = await _showGothicConfirmDialog(
                      context,
                      title: tr ? 'Değişiklikleri Kaydet' : 'Save Changes',
                      content: tr
                          ? 'Katalog taslağını kaydetmek istediğinize emin misiniz?'
                          : 'Are you sure you want to save the catalog draft?',
                    );
                    if (!confirmed) return;

                    await _saveCatalogDraft(context, draft);
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

              final announcementCard = const _AnnouncementForm(key: ValueKey('admin-announcement-form'));

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
                              _entryName(context, entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _entrySubtitle(context, entry),
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
                                  onPressed: _isTemplateEntry(entry)
                                      ? null
                                      : () async {
                                          final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                          final confirmed = await _showGothicConfirmDialog(
                                            context,
                                            title: tr ? 'Öğeyi Sil' : 'Delete Item',
                                            content: tr
                                                ? '${_entryName(context, entry)} öğesini katalogdan silmek istediğinize emin misiniz?'
                                                : 'Are you sure you want to delete ${_entryName(context, entry)} from catalog?',
                                          );
                                          if (confirmed) {
                                            _deleteCatalogEntry(entry.id);
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
    final confirmed = await _showGothicConfirmDialog(
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
          _deleteCatalogEntry(id);
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
          final name = _entryName(context, entry).toLowerCase();
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
                                            _entryName(context, entry),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Text(
                                            _catalogTypeLabel(context, entry.type),
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
                                            onPressed: _isTemplateEntry(entry)
                                                ? null
                                                : () async {
                                                    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                                                    final confirmed = await _showGothicConfirmDialog(
                                                      context,
                                                      title: tr ? 'Öğeyi Sil' : 'Delete Item',
                                                      content: tr
                                                          ? '${_entryName(context, entry)} öğesini katalogdan silmek istediğinize emin misiniz?'
                                                          : 'Are you sure you want to delete ${_entryName(context, entry)} from catalog?',
                                                    );
                                                    if (confirmed) {
                                                      _deleteCatalogEntry(entry.id);
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
  String formattedTime = _formatMessageTime(report.createdAt);

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
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? DollDexTheme.teal.withOpacity(0.5)
              : DollDexTheme.teal.withOpacity(0.3),
          width: 1,
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
                _buildNeonFlagIcon(context, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reportReasonLabel(context, report.reason),
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
                      label: Text(_reportStatusLabel(context, report.status)),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: DollDexTheme.teal.withOpacity(0.3)),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      icon: _buildNeonIcon(context, Icons.more_vert_rounded, size: 22),
                      tooltip: tr ? 'İşlemler' : 'Actions',
                      onSelected: (value) async {
                        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
                        switch (value) {
                          case 'open':
                            _openReportTarget(context, report);
                            break;
                          case 'reviewing':
                            final confirmed = await _showGothicConfirmDialog(
                              context,
                              title: tr ? 'İncelemeye Al' : 'Mark as Reviewing',
                              content: tr
                                  ? 'Bu raporu incelemeye almak istiyor musunuz?'
                                  : 'Do you want to mark this report as under review?',
                            );
                            if (confirmed) {
                              _updateReportStatus(report.id, ReportStatus.reviewing);
                            }
                            break;
                          case 'dismissed':
                            final confirmed = await _showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Reddet' : 'Dismiss Report',
                              content: tr
                                  ? 'Bu raporu reddetmek/kapatmak istiyor musunuz?'
                                  : 'Do you want to dismiss and close this report?',
                            );
                            if (confirmed) {
                              _updateReportStatus(report.id, ReportStatus.dismissed);
                            }
                            break;
                          case 'resolved':
                            final confirmed = await _showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Çöz' : 'Resolve Report',
                              content: tr
                                  ? 'Bu raporu çözüldü olarak işaretlemek istiyor musunuz?'
                                  : 'Do you want to mark this report as resolved?',
                            );
                            if (confirmed) {
                              _updateReportStatus(report.id, ReportStatus.resolved);
                            }
                            break;
                          case 'delete':
                            final confirmed = await _showGothicConfirmDialog(
                              context,
                              title: tr ? 'Raporu Sil' : 'Delete Report',
                              content: tr
                                  ? 'Bu rapor kaydını silmek istiyor musunuz?'
                                  : 'Do you want to delete this report record?',
                            );
                            if (confirmed) {
                              _deleteReport(report.id);
                            }
                            break;
                          case 'destroy':
                            await _deleteReportedContent(context, report);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              _buildNeonIcon(context, Icons.open_in_new_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'openTarget')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reviewing',
                          child: Row(
                            children: [
                              _buildNeonIcon(context, Icons.visibility_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'markReviewing')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'dismissed',
                          child: Row(
                            children: [
                              _buildNeonIcon(context, Icons.block_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'dismissReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Row(
                            children: [
                              _buildNeonIcon(context, Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(t(context, 'resolveReport')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              _buildNeonIcon(context, Icons.delete_outline_rounded, size: 18),
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
                                _buildNeonIcon(context, Icons.delete_forever_rounded, size: 18),
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

// _buildCompactAdminButton removed since PopUpMenuButton is now used.

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
    router.push('/catalog/${report.targetId}');
  } else if (report.targetType == ReportTargetType.profile || report.targetType == ReportTargetType.user) {
    router.push('/users/${report.targetId}');
  } else if (report.targetType == ReportTargetType.collectionEntry) {
    router.push('/collection/entry/${report.targetId}');
  } else if (report.targetType == ReportTargetType.comment) {
    FirebaseFirestore.instance.collection('comments').doc(report.targetId).get().then((doc) {
      if (doc.exists) {
        final targetType = doc.data()?['targetType'] as String?;
        final targetId = doc.data()?['targetId'] as String?;
        if (targetType == 'catalogEntry') {
          router.push('/catalog/$targetId');
        } else if (targetType == 'collectionEntry') {
          router.push('/collection/entry/$targetId');
        } else if (targetType == 'profile') {
          router.push('/users/$targetId');
        } else {
          router.push('/social');
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

class FeatureLine extends StatelessWidget {
  const FeatureLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: DollDexTheme.teal),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF2FF),
                border: Border.all(
                  color: const Color(0xFFEC008C),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC008C).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _buildNeonIcon(context, icon, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GothicPageBackgroundPainter extends CustomPainter {
  GothicPageBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isDark
        ? const Color(0xFFEC008C).withOpacity(0.12)
        : const Color(0xFF7B2CBF).withOpacity(0.08);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final motifs = [
      Icons.favorite_rounded,
      Icons.brightness_3_rounded,
      Icons.key_rounded,
      Icons.nights_stay_rounded,
      Icons.castle_rounded,
      Icons.auto_awesome_rounded,
      Icons.gavel_rounded,
      Icons.shield_rounded,
    ];

    final double stepX = 140;
    final double stepY = 160;
    int index = 0;

    for (double y = 40; y < size.height; y += stepY) {
      final double startX = (index % 2 == 0) ? 30 : 90;
      for (double x = startX; x < size.width; x += stepX) {
        final icon = motifs[index % motifs.length];
        
        textPainter.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 28,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GothicPageBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class GothicPageBackgroundWidget extends StatelessWidget {
  const GothicPageBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: GothicPageBackgroundPainter(isDark: isDark),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF160E24) : const Color(0xFFFAF6FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF00FFCC).withOpacity(0.25)
                                : const Color(0xFFEC008C).withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C)).withOpacity(0.08),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNeonIcon(context, Icons.info_outline_rounded, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFC4B2D9) : const Color(0xFF6B5885),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SampleCatalog {
  static CatalogEntry findById(String id) {
    return items.firstWhere(
      (item) => item.id == id,
      orElse: () => const CatalogEntry(
        id: 'missing',
        name: 'Catalog entry not found',
        type: CatalogItemType.doll,
        subtitle: 'This item may have been removed or is not available yet.',
        imageUrls: [],
        tags: ['missing'],
      ),
    );
  }

  static const items = [
    CatalogEntry(
      id: 'template-character',
      name: 'Character Profile',
      type: CatalogItemType.character,
      subtitle: 'Wiki entry template',
      imageUrls: [],
      tags: ['character', 'wiki'],
    ),
    CatalogEntry(
      id: 'template-doll',
      name: 'Doll Release',
      type: CatalogItemType.doll,
      subtitle: 'Owned, wanted, trade',
      imageUrls: [],
      tags: ['doll', 'release'],
    ),
    CatalogEntry(
      id: 'template-pet',
      name: 'Pet Companion',
      type: CatalogItemType.pet,
      subtitle: 'Linked to character',
      imageUrls: [],
      tags: ['pet'],
    ),
    CatalogEntry(
      id: 'template-accessory',
      name: 'Accessory Piece',
      type: CatalogItemType.accessory,
      subtitle: 'Set completion item',
      imageUrls: [],
      tags: ['accessory', 'completion'],
    ),
  ];
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

class CollectionCategoryTab extends StatefulWidget {
  const CollectionCategoryTab({
    required this.entries,
    super.key,
  });

  final List<CollectionEntry> entries;

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
    return _buildCollectionCategoryTab(context, widget.entries);
  }
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
          onTap: () => context.push('/collection/entry/${entry.id}'),
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

class UserCollectionEntryDetailScreen extends StatefulWidget {
  const UserCollectionEntryDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  State<UserCollectionEntryDetailScreen> createState() =>
      _UserCollectionEntryDetailScreenState();
}

class _UserCollectionEntryDetailScreenState
    extends State<UserCollectionEntryDetailScreen> {
  final _commentController = TextEditingController();
  Future<CollectionEntry?>? _entryFuture;

  @override
  void initState() {
    super.initState();
    _entryFuture = collectionRepository.fetch(widget.entryId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showEditCollectionSheet(BuildContext context, CatalogEntry item, CollectionEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return CollectionActionSheet(
          item: item,
          initialEntry: entry,
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
            final updatedEntry = CollectionEntry(
              id: entry.id,
              userId: userId,
              itemId: draft.itemId,
              status: draft.status,
              condition: draft.condition,
              quantity: draft.quantity,
              notes: draft.notes,
              isPublic: draft.isPublic,
            );
            collectionEntriesNotifier.value = [
              updatedEntry,
              ...collectionEntriesNotifier.value.where(
                (existing) => existing.id != entry.id,
              ),
            ];
            collectionRepository.save(updatedEntry).catchError((Object error) {
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
            if (mounted) {
              setState(() {
                _entryFuture = collectionRepository.fetch(widget.entryId);
              });
            }
            return true;
          },
        );
      },
    );
  }

  IconData _typeIcon(CatalogItemType type) {
    return switch (type) {
      CatalogItemType.character => Icons.face_retouching_natural_rounded,
      CatalogItemType.doll => Icons.face_3_outlined,
      CatalogItemType.set => Icons.inventory_2_outlined,
      CatalogItemType.pet => Icons.pets_rounded,
      CatalogItemType.accessory => Icons.earbuds_rounded,
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
  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageShell(
      title: tr ? 'Koleksiyon Parçası Detayı' : 'Collection Item Detail',
      subtitle: tr ? 'Koleksiyoner rafındaki detaylı bilgiler' : 'Detailed information on collector shelf',
      child: FutureBuilder<CollectionEntry?>(
        future: _entryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Hata / Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
          final entry = snapshot.data;
          if (entry == null) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: t(context, 'entryNotFound'),
              body: t(context, 'entryNotFoundBody'),
            );
          }

          final item = _findCatalogEntry(entry.itemId);

          final isPng = item.primaryImageUrl.toLowerCase().contains('.png');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: isPng ? Colors.transparent : null,
                elevation: isPng ? 0 : null,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: item.imageUrls.length > 1
                              ? PageView.builder(
                                  itemCount: item.imageUrls.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => _showPhotoGalleryDialog(context, item.imageUrls, index),
                                      child: DollImage(
                                        imageUrl: item.imageUrls[index],
                                        label: _entryName(context, item),
                                      ),
                                    );
                                  },
                                )
                              : GestureDetector(
                                  onTap: () => _showPhotoGalleryDialog(
                                    context,
                                    item.imageUrls.isNotEmpty ? item.imageUrls : [item.primaryImageUrl],
                                    0,
                                  ),
                                  child: DollImage(
                                    imageUrl: item.primaryImageUrl,
                                    label: _entryName(context, item),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder<int>(
                                stream: socialRepository.watchLikesCount('collectionEntry', entry.id),
                                builder: (context, likesSnap) {
                                  final count = likesSnap.data ?? 0;
                                  return StreamBuilder<bool>(
                                    stream: currentUser != null
                                        ? socialRepository.watchIsLiked(currentUser.uid, 'collectionEntry', entry.id)
                                        : Stream.value(false),
                                    builder: (context, isLikedSnap) {
                                      final isLiked = isLikedSnap.data ?? false;
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildGothicNeonIconButton(
                                            context: context,
                                            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 16,
                                            padding: const EdgeInsets.all(8),
                                            onPressed: currentUser == null
                                                ? null
                                                : () async {
                                                    if (isLiked) {
                                                      await socialRepository.unlikeTarget(
                                                        userId: currentUser.uid,
                                                        targetType: 'collectionEntry',
                                                        targetId: entry.id,
                                                      );
                                                    } else {
                                                      await socialRepository.likeTarget(
                                                        userId: currentUser.uid,
                                                        targetType: 'collectionEntry',
                                                        targetId: entry.id,
                                                      );
                                                    }
                                                  },
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFFEC008C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<List<AppComment>>(
                                stream: commentRepository.watchForTarget(
                                  targetType: 'collectionEntry',
                                  targetId: entry.id,
                                ),
                                builder: (context, commentsSnap) {
                                  final count = commentsSnap.data?.length ?? 0;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildGothicNeonIconButton(
                                        context: context,
                                        icon: Icons.mode_comment_outlined,
                                        size: 16,
                                        padding: const EdgeInsets.all(8),
                                        activeColor: const Color(0xFF00FFCC),
                                        onPressed: () => _showCommentsSheet(context, entry.id),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFFEC008C),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          shadows: isDark ? [
                                            const Shadow(color: Colors.black87, blurRadius: 4),
                                          ] : null,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _entryName(context, item),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                              _buildNeonIcon(context, _typeIcon(item.type), size: 24),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _entrySubtitle(context, item),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (item.year != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${tr ? 'Yıl' : 'Year'}: ${item.year}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr ? 'Koleksiyon Durumu' : 'Collection Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if ((currentUser != null && entry.userId == currentUser.uid) || (entry.userId == 'local-user'))
                            _buildGothicNeonIconButton(
                              context: context,
                              icon: Icons.edit_rounded,
                              size: 16,
                              padding: const EdgeInsets.all(8),
                              activeColor: const Color(0xFF00FFCC),
                              onPressed: () {
                                _showEditCollectionSheet(context, item, entry);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.inventory_2_outlined,
                              label: tr ? 'Adet' : 'Qty',
                              value: '${entry.quantity}',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.fact_check_outlined,
                              label: tr ? 'Durum' : 'Cond.',
                              value: _conditionLabel(context, entry.condition),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: Icons.bookmark_outline_rounded,
                              label: tr ? 'Statü' : 'Status',
                              value: _collectionStatusLabel(context, entry.status),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GothicStatButton(
                              icon: entry.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                              label: tr ? 'Erişim' : 'Access',
                              value: entry.isPublic ? (tr ? 'Açık' : 'Public') : (tr ? 'Gizli' : 'Private'),
                            ),
                          ),
                        ],
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          tr ? 'Koleksiyoner Notları' : 'Collector Notes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.notes,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<ProfileSetupStatus>(
                stream: profileSetupRepository.watch(entry.userId),
                builder: (context, ownerSnap) {
                  if (!ownerSnap.hasData) {
                    return const SizedBox();
                  }
                  final owner = ownerSnap.data!;
                  return Card(
                    child: ListTile(
                      leading: _buildAvatarHelper(owner.avatarId, owner.avatarFrameColor, size: 40),
                      title: Text(owner.username.isEmpty ? 'Collector' : '@${owner.username}'),
                      subtitle: Text(tr ? 'Koleksiyoncu profili için tıklayın' : 'Tap to view collector profile'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/users/${entry.userId}'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
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

void _showConnectionsModal(BuildContext context, String userId) {
  final currentUserId = authService.currentUser?.uid;
  final isOwnProfile = currentUserId == userId;
  final tabsCount = isOwnProfile ? 4 : 3;
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
                                  Navigator.of(context).pop();
                                  context.push('/users/${user.id}');
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
                                  Navigator.of(context).pop();
                                  context.push('/users/${user.id}');
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
                                  Navigator.of(context).pop();
                                  context.push('/users/${user.id}');
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

class MyReportsCard extends StatelessWidget {
  const MyReportsCard({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

    return StreamBuilder<List<UserReport>>(
      stream: reportService.watchReportsForUser(userId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr ? 'Raporlarım' : 'My Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final report = list[index];
                    return FutureBuilder<String>(
                      future: _resolveReportTargetText(report),
                      builder: (context, targetSnap) {
                        final targetText = targetSnap.data ?? report.targetId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildNeonFlagIcon(context, size: 20),
                          title: Text(
                            '${_reportReasonLabel(context, report.reason)}: $targetText',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            report.details.isNotEmpty ? report.details : (tr ? 'Detay yok' : 'No details'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(report.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _statusColor(report.status), width: 1),
                            ),
                            child: Text(
                              _reportStatusLabel(context, report.status),
                              style: TextStyle(
                                color: _statusColor(report.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(ReportStatus status) {
    return switch (status) {
      ReportStatus.open => Colors.orange,
      ReportStatus.reviewing => Colors.purpleAccent,
      ReportStatus.resolved => Colors.green,
      ReportStatus.dismissed => Colors.grey,
    };
  }
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

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({super.key});

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
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

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      prefixIcon: _buildNeonIcon(context, icon, size: 20),
      alignLabelWithHint: true,
      labelStyle: const TextStyle(fontFamily: 'Cinzel'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFEC008C), Color(0xFF7B2CBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC008C).withOpacity(0.4),
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
            fontFamily: 'Cinzel',
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
          backgroundColor: const Color(0xFF130820),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEC008C), width: 1.5),
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
                style: const TextStyle(color: Color(0xFF00FFCC)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC008C),
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
                    tr ? 'Henüz yayınlanmış duyuru yok.' : 'No announcements published yet.',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
                      title: Text(ann.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(ann.body),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text(tr ? 'Duyuruyu Sil' : 'Delete Announcement'),
                              content: Text(tr ? 'Bu duyuruyu tüm kullanıcılardan silmek istediğinize emin misiniz?' : 'Are you sure you want to delete this announcement from all users?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(tr ? 'İptal' : 'Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                  child: Text(tr ? 'Sil' : 'Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notificationRepository.deleteAnnouncement(ann.deepLink);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tr ? 'Duyuru silindi' : 'Announcement deleted')),
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
      subtitle: tr ? 'Geliştiricilerden önemli güncellemeler' : 'Important updates from the developers',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF130820) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFEC008C),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC008C).withOpacity(0.2),
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
                    _buildNeonIcon(context, Icons.campaign_outlined, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'Cinzel',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF2C1F45), height: 32, thickness: 1.2),
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
                      backgroundColor: const Color(0xFF160E24),
                      foregroundColor: const Color(0xFF00FFCC),
                      side: const BorderSide(color: Color(0xFF00FFCC), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

void _showCommentsSheet(BuildContext context, String targetId) {
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
                                    context.push('/users/${comment.userId}');
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
                                          context.push('/users/${comment.userId}');
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

class _GothicImageSlider extends StatefulWidget {
  const _GothicImageSlider({
    required this.imageUrls,
    required this.label,
  });

  final List<String> imageUrls;
  final String label;

  @override
  State<_GothicImageSlider> createState() => _GothicImageSliderState();
}

class _GothicImageSliderState extends State<_GothicImageSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showPhotoGalleryDialog(context, widget.imageUrls, index),
              child: DollImage(
                imageUrl: widget.imageUrls[index],
                label: widget.label,
              ),
            );
          },
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEC008C).withOpacity(0.5),
                width: 1.0,
              ),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.imageUrls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
      ],
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
                      _buildNeonIcon(context, Icons.people_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr ? 'Gelen Arkadaşlık İstekleri' : 'Incoming Friend Requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC008C),
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
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Row(
                        children: [
                          _buildAvatarHelper(req.sender.avatarId, req.sender.avatarFrameColor, size: 36),
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
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            onPressed: () => _respond(context, req.sender.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC).withOpacity(0.15),
                              foregroundColor: const Color(0xFF00FFCC),
                              side: const BorderSide(color: Color(0xFF00FFCC), width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            onPressed: () => _respond(context, req.sender.id, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEC008C),
                              side: const BorderSide(color: Color(0xFFEC008C), width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  Future<void> _respond(BuildContext context, String fromUserId, bool accept) async {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final confirmed = await _showGothicConfirmDialog(
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
        child: _DirectMessagesModalContent(initialChatUserId: initialChatUserId),
      );
    },
  );
}

void _openDirectChatWithUser(BuildContext context, String otherUserId) {
  _openDirectMessagesModal(context, initialChatUserId: otherUserId);
}

class _DirectMessagesModalContent extends StatefulWidget {
  const _DirectMessagesModalContent({
    this.initialChatUserId,
    this.showDragHandle = true,
  });
  final String? initialChatUserId;
  final bool showDragHandle;

  @override
  State<_DirectMessagesModalContent> createState() => _DirectMessagesModalContentState();
}

class _DirectMessagesModalContentState extends State<_DirectMessagesModalContent> {
  String? _activeThreadId;
  String? _activeChatUserId;
  bool _showFriendsSelection = false;
  bool _isLoading = false;

  List<String> _mutedThreadIds = [];
  List<String> _deletedThreadIds = [];
  Map<String, String> _lastReadTimes = {};

  @override
  void initState() {
    super.initState();
    _loadMutedAndDeleted();
    if (widget.initialChatUserId != null) {
      _startChatWithUser(widget.initialChatUserId!);
    }
  }

  Future<void> _loadMutedAndDeleted() async {
    final muted = await LocalStorage.getStringList('muted_threads');
    final deleted = await LocalStorage.getStringList('deleted_threads');
    final readTimesRaw = await LocalStorage.getString('last_read_times');
    Map<String, String> readTimes = {};
    if (readTimesRaw != null) {
      try {
        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _mutedThreadIds = muted;
        _deletedThreadIds = deleted;
        _lastReadTimes = readTimes;
      });
    }
  }

  Future<void> _muteThread(String threadId) async {
    final updated = List<String>.from(_mutedThreadIds);
    if (updated.contains(threadId)) {
      updated.remove(threadId);
    } else {
      updated.add(threadId);
    }
    await LocalStorage.setStringList('muted_threads', updated);
    setState(() {
      _mutedThreadIds = updated;
    });
  }

  Future<void> _deleteThread(String threadId) async {
    final updated = List<String>.from(_deletedThreadIds);
    if (!updated.contains(threadId)) {
      updated.add(threadId);
    }
    await LocalStorage.setStringList('deleted_threads', updated);
    setState(() {
      _deletedThreadIds = updated;
    });
  }

  Future<void> _markThreadAsRead(String threadId) async {
    final updated = Map<String, String>.from(_lastReadTimes);
    updated[threadId] = DateTime.now().toIso8601String();
    await LocalStorage.setString('last_read_times', jsonEncode(updated));
    if (mounted) {
      setState(() {
        _lastReadTimes = updated;
      });
    }
  }

  bool _isThreadUnread(ChatThread thread, String myUid) {
    if (thread.lastMessageSenderId == myUid) return false;
    if (thread.lastMessagePreview.isEmpty) return false;
    final lastReadStr = _lastReadTimes[thread.id];
    if (lastReadStr == null) return true;
    if (thread.updatedAt == null) return false;
    final lastRead = DateTime.tryParse(lastReadStr);
    if (lastRead == null) return true;
    return thread.updatedAt!.isAfter(lastRead);
  }

  Future<void> _startChatWithUser(String otherUserId) async {
    final myUid = authService.currentUser?.uid;
    if (myUid == null) return;
    setState(() => _isLoading = true);
    try {
      final threadId = await socialRepository.openDirectThread(
        currentUserId: myUid,
        otherUserId: otherUserId,
      );
      if (mounted) {
        setState(() {
          _activeThreadId = threadId;
          _activeChatUserId = otherUserId;
          _showFriendsSelection = false;
          _isLoading = false;
        });
        _markThreadAsRead(threadId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet başlatılamadı: $e')),
        );
      }
    }
  }

  void _backToInbox() {
    _loadMutedAndDeleted();
    setState(() {
      _activeThreadId = null;
      _activeChatUserId = null;
      _showFriendsSelection = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final myUid = authService.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (myUid.isEmpty) {
      return Center(
        child: Text(
          tr ? 'Lütfen önce giriş yapın' : 'Please sign in first',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEC008C)));
    }

    Widget header;
    Widget body;

    if (_activeThreadId != null && _activeChatUserId != null) {
      header = Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          StreamBuilder<ProfileSetupStatus>(
            stream: profileSetupRepository.watch(_activeChatUserId!),
            builder: (context, snap) {
              final username = snap.data?.username.isNotEmpty == true ? '@${snap.data!.username}' : 'Collector';
              final avatarId = snap.data?.avatarId ?? '';
              final frameColor = snap.data?.avatarFrameColor ?? '';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.showDragHandle) {
                    Navigator.of(context).pop();
                  }
                  context.push('/users/${_activeChatUserId}');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      _buildAvatarHelper(avatarId, frameColor, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
      body = Expanded(
        child: _DirectChatConversationView(
          threadId: _activeThreadId!,
          otherUserId: _activeChatUserId!,
          myUid: myUid,
        ),
      );
    } else if (_showFriendsSelection) {
      header = Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: _backToInbox,
          ),
          const SizedBox(width: 8),
          Text(
            tr ? 'Yeni Sohbet' : 'New Chat',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      );
      body = Expanded(
        child: StreamBuilder<List<AppUser>>(
          stream: socialRepository.watchFriendsList(myUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final friends = snap.data ?? [];
            if (friends.isEmpty) {
              return Center(
                child: Text(
                  tr ? 'Sohbet başlatacak arkadaşınız yok' : 'No friends to start chat with',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                ),
              );
            }
            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, idx) {
                final friend = friends[idx];
                return ListTile(
                  leading: _buildAvatarHelper(friend.avatarId, friend.avatarFrameColor, size: 36),
                  title: Text(
                    friend.username.isEmpty ? friend.displayName : '@${friend.username}',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(friend.displayName, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  onTap: () => _startChatWithUser(friend.id),
                );
              },
            );
          },
        ),
      );
    } else {
      header = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr ? 'Özel Mesajlar' : 'Direct Messages',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_rounded, color: Color(0xFFEC008C)),
              onPressed: () => setState(() => _showFriendsSelection = true),
            ),
          ],
        ),
      );

      body = Expanded(
        child: StreamBuilder<List<ChatThread>>(
          stream: socialRepository.watchChatThreads(myUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allThreads = snap.data ?? [];
            final threads = allThreads.where((t) => !_deletedThreadIds.contains(t.id)).toList();
            if (threads.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      tr ? 'Henüz konuşma yok' : 'No conversations yet',
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: threads.length,
              itemBuilder: (context, idx) {
                final thread = threads[idx];
                final otherMemberId = thread.memberIds.firstWhere((id) => id != myUid, orElse: () => '');
                if (otherMemberId.isEmpty) return const SizedBox.shrink();

                return _ThreadListTile(
                  thread: thread,
                  otherUserId: otherMemberId,
                  onTap: () {
                    setState(() {
                      _activeThreadId = thread.id;
                      _activeChatUserId = otherMemberId;
                    });
                    _markThreadAsRead(thread.id);
                  },
                  isMuted: _mutedThreadIds.contains(thread.id),
                  hasUnread: _isThreadUnread(thread, myUid),
                  onMute: () => _muteThread(thread.id),
                  onDelete: () => _deleteThread(thread.id),
                );
              },
            );
          },
        ),
      );
    }

    return Column(
      children: [
        if (widget.showDragHandle) ...[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 8),
        header,
        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
        body,
      ],
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.thread,
    required this.otherUserId,
    required this.onTap,
    required this.isMuted,
    required this.hasUnread,
    required this.onMute,
    required this.onDelete,
  });

  final ChatThread thread;
  final String otherUserId;
  final VoidCallback onTap;
  final bool isMuted;
  final bool hasUnread;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileSetupStatus>(
      stream: profileSetupRepository.watch(otherUserId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 60);
        }
        final status = snap.data!;
        final username = status.username.isNotEmpty ? '@${status.username}' : 'Collector';
        final displayName = status.displayName;
        final avatarId = status.avatarId;
        final frameColor = status.avatarFrameColor;

        final myUid = authService.currentUser?.uid ?? '';
        final isMe = thread.lastMessageSenderId == myUid;
        final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
        final prefix = isMe ? (tr ? 'Siz: ' : 'You: ') : '';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListTile(
          onTap: onTap,
          leading: _buildAvatarHelper(avatarId, frameColor, size: 40),
          title: Text(
            username,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Row(
            children: [
              if (hasUnread) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEC008C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isMuted) ...[
                Icon(Icons.volume_off_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  thread.lastMessagePreview.isNotEmpty
                      ? '$prefix${thread.lastMessagePreview}'
                      : displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
              if (thread.updatedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatMessageTime(thread.updatedAt!),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white24 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white30 : Colors.black38),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'mute') {
                onMute();
              } else if (val == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(
                  isMuted
                      ? (tr ? 'Sesi Aç' : 'Unmute')
                      : (tr ? 'Sessize Al' : 'Mute'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  tr ? 'Sohbeti Sil' : 'Delete',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DirectChatConversationView extends StatefulWidget {
  const _DirectChatConversationView({
    required this.threadId,
    required this.otherUserId,
    required this.myUid,
  });

  final String threadId;
  final String otherUserId;
  final String myUid;

  @override
  State<_DirectChatConversationView> createState() => _DirectChatConversationViewState();
}

class _DirectChatConversationViewState extends State<_DirectChatConversationView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();
    await socialRepository.sendDirectMessage(
      threadId: widget.threadId,
      senderId: widget.myUid,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: socialRepository.watchDirectMessages(widget.threadId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snap.data ?? [];
              if (messages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  LocalStorage.getString('last_read_times').then((readTimesRaw) {
                    Map<String, String> readTimes = {};
                    if (readTimesRaw != null) {
                      try {
                        readTimes = Map<String, String>.from(jsonDecode(readTimesRaw) as Map);
                      } catch (_) {}
                    }
                    readTimes[widget.threadId] = DateTime.now().toIso8601String();
                    LocalStorage.setString('last_read_times', jsonEncode(readTimes));
                  });
                });
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    tr ? 'Konuşmayı başlatın...' : 'Start the conversation...',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  final isMe = msg.senderId == widget.myUid;
                  return _buildDirectMsgBubble(context, msg, isMe);
                },
              );
            },
          ),
        ),
        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
          ),
          color: isDark ? const Color(0xFF171026) : const Color(0xFFFAF2FF),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr ? 'Mesaj yaz...' : 'Write message...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFFEC008C)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectMsgBubble(BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
            minWidth: 50,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C1F45), const Color(0xFF1C1330)]
                        : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13.5,
                ),
              ),
              if (msg.createdAt != null) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatMessageTime(msg.createdAt!),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 8.5,
                      color: isMe ? Colors.white70 : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SafeShaderMask extends StatelessWidget {
  const SafeShaderMask({
    required this.shaderCallback,
    required this.child,
    this.fallbackColor,
    this.blendMode = BlendMode.modulate,
    super.key,
  });

  final Shader Function(Rect) shaderCallback;
  final Widget child;
  final Color? fallbackColor;
  final BlendMode blendMode;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (child is Icon) {
        final icon = child as Icon;
        return Icon(
          icon.icon,
          key: icon.key,
          size: icon.size,
          color: fallbackColor ?? const Color(0xFFEC008C),
          semanticLabel: icon.semanticLabel,
          textDirection: icon.textDirection,
          shadows: icon.shadows,
        );
      } else if (child is Text) {
        final text = child as Text;
        final originalStyle = text.style;
        final newStyle = (originalStyle ?? const TextStyle()).copyWith(
          color: fallbackColor ?? const Color(0xFFEC008C),
        );
        return Text(
          text.data ?? '',
          key: text.key,
          style: newStyle,
          strutStyle: text.strutStyle,
          textAlign: text.textAlign,
          textDirection: text.textDirection,
          locale: text.locale,
          softWrap: text.softWrap,
          overflow: text.overflow,
          textScaler: text.textScaler,
          maxLines: text.maxLines,
          semanticsLabel: text.semanticsLabel,
          textWidthBasis: text.textWidthBasis,
          textHeightBehavior: text.textHeightBehavior,
          selectionColor: text.selectionColor,
        );
      }
      return child;
    }
    return ShaderMask(
      shaderCallback: shaderCallback,
      blendMode: blendMode,
      child: child,
    );
  }
}
