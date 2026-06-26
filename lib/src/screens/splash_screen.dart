import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showDots = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.85, end: 1.03), weight: 30),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.03, end: 0.97), weight: 35),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.97, end: 1.0), weight: 15),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.05), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _showDots = true);
      }
    });

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double scaleVal = _scaleAnimation.value;
          final double fadeVal = _fadeAnimation.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              const GothicPageBackgroundWidget(),

              // Central Pulsing App Name
              Center(
                child: Opacity(
                  opacity: fadeVal,
                  child: Transform.scale(
                    scale: scaleVal,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark
                                ? DollDexTheme.darkPanel
                                : DollDexTheme.panel,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark
                                  ? DollDexTheme.darkLine
                                  : DollDexTheme.line,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.26 : 0.12),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.collections_bookmark_rounded,
                            size: 40,
                            color: DollDexTheme.teal,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t(context, 'appName'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFFE7D2B8)
                                : DollDexTheme.ink,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLanguageScope.languageOf(context) == AppLanguage.tr
                              ? 'Online Bebek Koleksiyonu'
                              : 'Online Doll Collection',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFE7D2B8).withOpacity(0.8)
                                : DollDexTheme.cocoa,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: AnimatedOpacity(
                  opacity: _showDots ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final pulse =
                              (((_controller.value * 3) + index) % 1.0);
                          return Opacity(
                            opacity: 0.45 + (pulse * 0.55),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
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
