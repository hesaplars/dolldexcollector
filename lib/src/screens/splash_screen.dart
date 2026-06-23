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
                          width: 86,
                          height: 86,
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
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 46,
                            color: DollDexTheme.teal,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t(context, 'appName'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFFE7D2B8) : DollDexTheme.ink,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLanguageScope.languageOf(context) == AppLanguage.tr
                              ? 'Online Bebek Koleksiyonu'
                              : 'Online Doll Collection',
                          style: TextStyle(
                            fontSize: 14,
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
            ],
          );
        },
      ),
    );
  }
}
