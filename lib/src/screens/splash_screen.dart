import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

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
