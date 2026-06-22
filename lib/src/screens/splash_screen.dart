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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.03), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.03, end: 0.97), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.97, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 20),
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
              CustomPaint(
                painter: GothicBackgroundPainter(themeBrightness: Theme.of(context).brightness),
              ),
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
                        Stack(
                          children: [
                            Text(
                              t(context, 'appName'),
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.transparent,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFEC008C).withOpacity(0.85),
                                    blurRadius: 15,
                                  ),
                                  Shadow(
                                    color: const Color(0xFF00FFCC).withOpacity(0.85),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
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
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLanguageScope.languageOf(context) == AppLanguage.tr
                              ? 'Online Bebek Koleksiyonu'
                              : 'Online Doll Collection',
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
              ),
            ],
          );
        },
      ),
    );
  }
}
