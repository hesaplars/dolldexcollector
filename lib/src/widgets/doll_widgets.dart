import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/app_language.dart';
import '../core/web_image_helper.dart';
import '../../main.dart';
import '../catalog/catalog_models.dart';
import '../users/profile_setup_repository.dart';
import '../notifications/notification_models.dart';
import '../core/app_helpers.dart';
import 'social_feed_tab.dart';

class DollDexTheme {
  static const ink = Color(0xFF1F1E1C);
  static const cocoa = Color(0xFF7A6652);
  static const paper = Color(0xFFF7EFE2);
  static const mist = Color(0xFFF4E7D3);
  static const panel = Color(0xFFFFF8EB);
  static const teal = Color(0xFFFF5A14);
  static const berry = Color(0xFF7A6652);
  static const amber = Color(0xFFC89411);
  static const line = Color(0xFFE5D6BF);
  static const softPeach = Color(0xFFFFE2C4);
  static const softLemon = Color(0xFFFFE2C4);
  static const darkInk = Color(0xFFFFF7EA);
  static const darkPaper = Color(0xFF15120F);
  static const darkPanel = Color(0xFF211A14);
  static const darkLine = Color(0xFF4A3828);

  static ThemeData get light => _buildPremiumTheme(
        brightness: Brightness.light,
        bg: const Color(0xFFF7EFE2),
        panel: const Color(0xFFFFF8EB),
        panelAlt: const Color(0xFFF4E7D3),
        text: const Color(0xFF1F1E1C),
        muted: const Color(0xFF7A6652),
        accent: const Color(0xFFFF5A14),
        accentSoft: const Color(0xFFFFE2C4),
        line: const Color(0xFFE5D6BF),
      );

  static ThemeData get dark => _buildPremiumTheme(
        brightness: Brightness.dark,
        bg: const Color(0xFF15120F),
        panel: const Color(0xFF211A14),
        panelAlt: const Color(0xFF2C2218),
        text: const Color(0xFFFFF7EA),
        muted: const Color(0xFFCBB9A4),
        accent: const Color(0xFFFF7A1A),
        accentSoft: const Color(0xFF3A2618),
        line: const Color(0xFF4A3828),
      );

  static ThemeData get toxicNeon => _buildPremiumTheme(
        brightness: Brightness.light,
        bg: const Color(0xFFEEF7EF),
        panel: const Color(0xFFFBFFF8),
        panelAlt: const Color(0xFFE0F0E6),
        text: const Color(0xFF17221A),
        muted: const Color(0xFF607463),
        accent: const Color(0xFF2D9D72),
        accentSoft: const Color(0xFFCDEEDC),
        line: const Color(0xFFC7DDCC),
      );

  static ThemeData get crimsonBlood => _buildPremiumTheme(
        brightness: Brightness.light,
        bg: const Color(0xFFFFF0EC),
        panel: const Color(0xFFFFF8F2),
        panelAlt: const Color(0xFFF8DCD4),
        text: const Color(0xFF241713),
        muted: const Color(0xFF7F5A50),
        accent: const Color(0xFFC53B2C),
        accentSoft: const Color(0xFFFFD8CE),
        line: const Color(0xFFE8C5BB),
      );

  static ThemeData get royalGold => _buildPremiumTheme(
        brightness: Brightness.light,
        bg: const Color(0xFFFFF7DF),
        panel: const Color(0xFFFFFDF3),
        panelAlt: const Color(0xFFF3E0AA),
        text: const Color(0xFF211B0E),
        muted: const Color(0xFF776033),
        accent: const Color(0xFFC89411),
        accentSoft: const Color(0xFFFFE6A6),
        line: const Color(0xFFE1C778),
      );

  static ThemeData getThemeData(String key) {
    switch (key) {
      case 'goth_light':
        return light;
      case 'toxic_neon':
        return toxicNeon;
      case 'crimson_blood':
        return crimsonBlood;
      case 'royal_gold':
        return royalGold;
      case 'goth_dark':
      default:
        return dark;
    }
  }

  static ThemeData _buildPremiumTheme({
    required Brightness brightness,
    required Color bg,
    required Color panel,
    required Color panelAlt,
    required Color text,
    required Color muted,
    required Color accent,
    required Color accentSoft,
    required Color line,
  }) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        primary: accent,
        primaryContainer: accentSoft,
        secondary: muted,
        secondaryContainer: panelAlt,
        surface: panel,
        onSurface: text,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
      ),
      iconTheme: IconThemeData(color: muted),
      dividerColor: line,
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black
            .withOpacity(brightness == Brightness.dark ? 0.28 : 0.1),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: line, width: 1.1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: line, width: 1.2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: line, width: 1.2),
        ),
        dragHandleColor: line,
        dragHandleSize: const Size(48, 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: accent.withOpacity(0.35),
          textStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: accent.withOpacity(0.35),
          textStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: muted,
          side: BorderSide(color: line, width: 1.5),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: panelAlt,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withOpacity(0.12),
        shadowColor: Colors.black.withOpacity(0.18),
        elevation: 12,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : muted.withOpacity(0.75),
            size: selected ? 28 : 25,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? accent : muted.withOpacity(0.72),
            overflow: TextOverflow.ellipsis,
            fontFamily: 'Outfit',
            height: 1.0,
          );
        }),
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
      ..color = (isDark ? const Color(0xFF00FFCC) : const Color(0xFFEC008C))
          .withOpacity(0.05)
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
          path.quadraticBezierTo(
              scale * 0.4, -scale * 0.5, scale * 0.8, -scale * 0.2);
          path.quadraticBezierTo(scale * 0.5, scale * 0.1, scale * 0.2, 0);
          path.quadraticBezierTo(0, scale * 0.3, -scale * 0.2, 0);
          path.quadraticBezierTo(
              -scale * 0.5, scale * 0.1, -scale * 0.8, -scale * 0.2);
          path.quadraticBezierTo(-scale * 0.4, -scale * 0.5, 0, -scale * 0.2);
          break;
        case 1: // Pumpkin
          path.addOval(Rect.fromCenter(
              center: Offset.zero, width: scale, height: scale * 0.8));
          path.moveTo(0, -scale * 0.4);
          path.quadraticBezierTo(
              scale * 0.1, -scale * 0.6, scale * 0.2, -scale * 0.5);
          break;
        case 2: // Heart
          path.moveTo(0, -scale * 0.3);
          path.cubicTo(scale * 0.4, -scale * 0.8, scale * 0.9, -scale * 0.2, 0,
              scale * 0.5);
          path.cubicTo(-scale * 0.9, -scale * 0.2, -scale * 0.4, -scale * 0.8,
              0, -scale * 0.3);
          break;
        case 3: // Crescent Moon
          path.addArc(
              Rect.fromCenter(center: Offset.zero, width: scale, height: scale),
              -math.pi / 2,
              math.pi);
          path.quadraticBezierTo(scale * 0.2, 0, 0, -scale / 2);
          break;
        case 4: // Skull
          path.addArc(
              Rect.fromCenter(
                  center: const Offset(0, -2),
                  width: scale * 0.7,
                  height: scale * 0.7),
              math.pi,
              math.pi);
          path.lineTo(scale * 0.25, scale * 0.3);
          path.lineTo(-scale * 0.25, scale * 0.3);
          path.close();
          break;
        case 5: // Spiderweb
          for (double r = 0.2; r <= 1.0; r += 0.4) {
            path.addOval(Rect.fromCenter(
                center: Offset.zero, width: scale * r, height: scale * r));
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
          path.addOval(Rect.fromCenter(
              center: Offset(0, -scale * 0.25),
              width: scale * 0.4,
              height: scale * 0.4));
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
    path.arcToPoint(Offset(w - r, h),
        radius: Radius.circular(r), clockwise: true);
    path.quadraticBezierTo(w * 0.75, h + 1, w * 0.5, h - 1);
    path.quadraticBezierTo(w * 0.25, h - 2, r, h);
    path.arcToPoint(Offset(0, h - r),
        radius: Radius.circular(r), clockwise: true);
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

    final bgCol = color ?? theme.colorScheme.surface;
    final borderCol = borderColor ?? theme.colorScheme.primary.withOpacity(0.5);

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

class GothicFrameWidget extends StatelessWidget {
  const GothicFrameWidget(
      {required this.frameType, required this.size, super.key});

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
        final glowPaint = Paint()
          ..color = const Color(0xFF00FFCC)
          ..style = PaintingStyle.fill;
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
          Offset(center.dx - radius * math.cos(angle),
              center.dy - radius * math.sin(angle)),
          Offset(center.dx + radius * math.cos(angle),
              center.dy + radius * math.sin(angle)),
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
        canvas.drawRect(const Rect.fromLTWH(-2, 2.5, 4, 3), skullPaint);
        // Eyes
        canvas.drawCircle(const Offset(-1.2, 0), 1.0, eyePaint);
        canvas.drawCircle(const Offset(1.2, 0), 1.0, eyePaint);

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
        canvas.drawRect(const Rect.fromLTWH(-1.2, -4.5, 2.4, 9), crossPaint);
        // Horizontal beam
        canvas.drawRect(const Rect.fromLTWH(-3.5, -2, 7, 2), crossPaint);

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
        ..addOval(
            Rect.fromCircle(center: const Offset(-2.0, -1.0), radius: 4.5));
      final finalMoon =
          Path.combine(PathOperation.difference, moonPath, cutPath);
      canvas.drawPath(finalMoon, moonPaint);
      canvas.restore();

      // Tiny stars at top-left
      canvas.drawCircle(
          Offset(center.dx - radius * 0.7, center.dy - radius * 0.7),
          1.2,
          starPaint);
      canvas.drawCircle(
          Offset(center.dx - radius * 0.5, center.dy - radius * 0.8),
          0.8,
          starPaint);
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
        canvas.drawLine(
            const Offset(0, -2.5), const Offset(0, 2.5), crossLinePaint);
        canvas.drawLine(
            const Offset(-1.2, -0.5), const Offset(1.2, -0.5), crossLinePaint);

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
    _drawCornerBat(canvas, const Offset(16, 16), batPaint); // Sol Üst
    _drawCornerBat(canvas, Offset(size.width - 16, 16), batPaint); // Sağ Üst
    _drawCornerBat(canvas, Offset(16, size.height - 16), batPaint); // Sol Alt
    _drawCornerBat(
        canvas, Offset(size.width - 16, size.height - 16), batPaint); // Sağ Alt
  }

  void _drawThorn(
      Canvas canvas, Offset position, double rotation, Paint paint) {
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
          color: fallbackColor ?? Theme.of(context).colorScheme.primary,
          semanticLabel: icon.semanticLabel,
          textDirection: icon.textDirection,
          shadows: icon.shadows,
        );
      } else if (child is Text) {
        final text = child as Text;
        final originalStyle = text.style;
        final newStyle = (originalStyle ?? const TextStyle()).copyWith(
          color: fallbackColor ?? Theme.of(context).colorScheme.primary,
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
          buildGothicNeonIconButton(
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 0,
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
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
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: buildNeonIcon(context, icon, size: 40),
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
          ),
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    final outlineColor = theme.colorScheme.outline;
    final surfaceColor = theme.colorScheme.surface;

    final bgColor =
        isDark ? surfaceColor.withOpacity(0.85) : surfaceColor.withOpacity(0.9);
    final borderColor = primaryColor;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: _isHovered
                ? (Matrix4.identity()..scale(1.03))
                : Matrix4.identity(),
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
                  color: primaryColor.withOpacity(
                      _glowAnimation.value * (_isHovered ? 1.4 : 1.0)),
                  blurRadius: (10 + (_glowAnimation.value * 15)) *
                      (_isHovered ? 1.2 : 1.0),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: secondaryColor.withOpacity(_glowAnimation.value * 0.4),
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
                        return LinearGradient(
                          colors: [primaryColor, secondaryColor],
                        ).createShader(bounds);
                      },
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
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
                      color: secondaryColor.withOpacity(0.5),
                    ),
                  ],
                ),
                Icon(
                  widget.icon,
                  size: 32,
                  color: primaryColor.withOpacity(0.85),
                ),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
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
                          backgroundColor:
                              theme.dialogTheme.backgroundColor ?? surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: primaryColor),
                          ),
                          title: Text(
                            widget.subtitle,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'DollDex Collector özel indirim kodunuz: ${widget.promoCode}\nKeyifli koleksiyonlar dileriz!',
                            style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.8)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Kapat',
                                  style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor, width: 1),
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(_isHovered ? 0.35 : 0.15),
                            secondaryColor
                                .withOpacity(_isHovered ? 0.35 : 0.15),
                          ],
                        ),
                      ),
                      child: const Text(
                        'KEŞFET',
                        style: TextStyle(
                          fontFamily: 'Outfit',
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
  State<GothicAdBannerHorizontal> createState() =>
      _GothicAdBannerHorizontalState();
}

class _GothicAdBannerHorizontalState extends State<GothicAdBannerHorizontal> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final outlineColor = theme.colorScheme.outline;
    final panelAltColor = theme.colorScheme.secondaryContainer;

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: outlineColor,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 60),
            painter: IvyBorderPainter(
              color: primaryColor.withOpacity(0.15),
            ),
          ),
          Center(
            child: Text(
              'ADVERTISEMENT',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Outfit',
                letterSpacing: 4,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GothicPageBackgroundPainter extends CustomPainter {
  GothicPageBackgroundPainter({
    required this.bg,
    required this.panelAlt,
    required this.line,
    required this.accent,
    required this.isDark,
  });

  final Color bg;
  final Color panelAlt;
  final Color line;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [bg, panelAlt],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final dotPaint = Paint()
      ..color = (isDark ? const Color(0xFFFFC48A) : const Color(0xFFB79268))
          .withOpacity(isDark ? 0.12 : 0.22)
      ..style = PaintingStyle.fill;
    const step = 34.0;
    for (double y = 16; y < size.height; y += step) {
      for (double x = 16; x < size.width; x += step) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 3, height: 3),
            const Radius.circular(1.5),
          ),
          dotPaint,
        );
      }
    }

    final linePaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF6B4328))
          .withOpacity(isDark ? 0.04 : 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.16)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.08,
          size.width * 0.58, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.36,
          size.width * 0.94, size.height * 0.2)
      ..moveTo(size.width * 0.1, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.5,
          size.width * 0.72, size.height * 0.68);
    canvas.drawPath(path, linePaint);

    final accentPaint = Paint()
      ..color = accent.withOpacity(isDark ? 0.11 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.08), 72, accentPaint);
    canvas.drawCircle(
        Offset(size.width * 0.08, size.height * 0.92), 96, accentPaint);
  }

  @override
  bool shouldRepaint(covariant GothicPageBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.bg != bg ||
      oldDelegate.panelAlt != panelAlt ||
      oldDelegate.line != line ||
      oldDelegate.accent != accent;
}

class GothicPageBackgroundWidget extends StatelessWidget {
  const GothicPageBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: GothicPageBackgroundPainter(
        bg: theme.scaffoldBackgroundColor,
        panelAlt: theme.colorScheme.secondaryContainer,
        line: theme.colorScheme.outline,
        accent: theme.colorScheme.primary,
        isDark: theme.brightness == Brightness.dark,
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.listViewKey,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Key? listViewKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        key: listViewKey,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showBackButton) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                          onPressed: onBack ??
                              () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: theme.brightness == Brightness.dark
                                    ? DollDexTheme.darkInk
                                    : DollDexTheme.ink,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DollDexTheme.darkPanel
                                : DollDexTheme.panel,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? DollDexTheme.darkLine
                                  : DollDexTheme.line,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.18 : 0.07),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildNeonIcon(context, Icons.info_outline_rounded,
                                  size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFE7D2B8)
                                        : DollDexTheme.cocoa,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
          ),
        ],
      ),
    );
  }
}

Widget buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
  return Icon(
    icon,
    color: Theme.of(context).colorScheme.primary,
    size: size,
  );
}

Widget buildGothicNeonIconButton({
  required BuildContext context,
  required IconData icon,
  VoidCallback? onPressed,
  double size = 20,
  EdgeInsets padding = const EdgeInsets.all(8),
  Color? activeColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final finalColor = activeColor ?? Theme.of(context).colorScheme.primary;

  final child = Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: isDark ? DollDexTheme.darkPanel : Colors.white,
      border: Border.all(
        color: isDark ? DollDexTheme.darkLine : DollDexTheme.line,
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: finalColor, size: size),
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

Widget buildNeonFlagIcon(BuildContext context, {double size = 24}) {
  return buildNeonIcon(context, Icons.flag_outlined, size: size);
}

Widget buildAvatarHelper(
    BuildContext context, String avatarId, String frameColor,
    {double size = 40}) {
  String assetPath = '';
  final theme = Theme.of(context);
  final primaryColor = theme.colorScheme.primary;
  final secondaryColor = theme.colorScheme.secondary;
  final outlineColor = theme.colorScheme.outline;
  final surfaceColor = theme.colorScheme.surface;

  final bool isNetwork =
      avatarId.startsWith('http://') || avatarId.startsWith('https://');

  if (isNetwork) {
    // Will be loaded via Image.network
  } else {
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
              color: primaryColor,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
            color: surfaceColor,
          ),
          child: Center(
            child: SafeShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [primaryColor, secondaryColor],
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
  }

  final isGothicFrame = frameColor.startsWith('frame-');
  final parsedColor =
      !isGothicFrame ? int.tryParse(frameColor, radix: 16) : null;
  final Color? borderColor = parsedColor != null ? Color(parsedColor) : null;
  final hasFrame = frameColor.isNotEmpty;

  Widget buildDefaultPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryColor,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
        color: surfaceColor,
      ),
      child: Center(
        child: SafeShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [primaryColor, secondaryColor],
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

  return Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: hasFrame
              ? Border.all(
                  color: borderColor ?? outlineColor.withOpacity(0.5),
                  width: borderColor != null ? 3.0 : 1.5,
                )
              : null,
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
          padding:
              EdgeInsets.all(borderColor != null || isGothicFrame ? 2.0 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size),
            child: isNetwork
                ? Image.network(
                    avatarId,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return buildDefaultPlaceholder();
                    },
                  )
                : Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return buildDefaultPlaceholder();
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

void showPhotoGalleryDialog(
    BuildContext context, List<String> imageUrls, int initialIndex) {
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
                    icon: buildNeonIcon(context, Icons.close_rounded, size: 24),
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

class GothicImageSlider extends StatefulWidget {
  const GothicImageSlider({
    required this.imageUrls,
    required this.label,
    super.key,
  });

  final List<String> imageUrls;
  final String label;

  @override
  State<GothicImageSlider> createState() => _GothicImageSliderState();
}

class _GothicImageSliderState extends State<GothicImageSlider> {
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
              onTap: () =>
                  showPhotoGalleryDialog(context, widget.imageUrls, index),
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

Widget buildCoverPhoto(BuildContext context, String? coverId,
    {required bool isPro}) {
  final showDefault =
      !isPro || coverId == null || coverId.isEmpty || coverId == 'default';

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
                    colors: [
                      Color(0xFF130820),
                      Color(0xFF2E0C4C),
                      Color(0xFFEC008C)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SafeShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Colors.white
                      ],
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
                      fontFamily: 'Outfit',
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          offset: const Offset(0, 1.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLanguageScope.languageOf(context) == AppLanguage.tr
                      ? 'Online Bebek Koleksiyonu'
                      : 'Online Doll Collection',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontFamily: 'Outfit',
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        offset: const Offset(0, 1.5),
                        blurRadius: 3,
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

Widget buildCoverPhotoPreview(String coverId) {
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
                    colors: [
                      Color(0xFF130820),
                      Color(0xFF2E0C4C),
                      Color(0xFFEC008C)
                    ],
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
                fontFamily: 'Outfit',
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

class GuestLoginBanner extends StatelessWidget {
  const GuestLoginBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Card(
          elevation: 2,
          color: isDark ? const Color(0xFF130B1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: const Color(0xFFEC008C).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF00FFCC),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr
                        ? 'Koleksiyonunu yedeklemek için giriş yap'
                        : 'Sign in to backup your collection',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () => context.push('/consent'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: const Color(0xFFEC008C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: Text(
                      tr ? 'Giriş Yap' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
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

class AvatarOption extends StatelessWidget {
  const AvatarOption({
    required this.avatarId,
    required this.selected,
    required this.frameColor,
    required this.onTap,
    super.key,
  });

  final String avatarId;
  final bool selected;
  final String frameColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: buildAvatarHelper(
          context,
          avatarId,
          selected ? frameColor : '',
          size: selected ? 52 : 56,
        ),
      ),
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    final outlineColor = theme.colorScheme.outline;
    final surfaceColor = theme.colorScheme.surface;
    final primaryContainerColor = theme.colorScheme.primaryContainer;

    final bgCol = primaryContainerColor.withOpacity(0.15);
    final borderCol = outlineColor.withOpacity(0.4);

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
            color: primaryColor.withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
              border: Border.all(
                color: primaryColor.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: buildNeonIcon(context, icon, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.0,
              color: secondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.color,
    required this.glowColor,
    required this.textColor,
    required this.descriptionTr,
    required this.descriptionEn,
    this.coinsPrice = 0,
    this.isProOnly = false,
    this.dollRequirement = 0,
    this.boxedRequirement = 0,
    this.characterRequirement = '',
    this.charCountRequirement = 0,
    this.commentsRequirement = 0,
  });

  final String id;
  final String nameTr;
  final String nameEn;
  final Color color;
  final Color glowColor;
  final Color textColor;
  final String descriptionTr;
  final String descriptionEn;
  final int coinsPrice;
  final bool isProOnly;
  final int dollRequirement;
  final int boxedRequirement;
  final String characterRequirement;
  final int charCountRequirement;
  final int commentsRequirement;

  String name(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return tr ? nameTr : nameEn;
  }

  String description(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    return tr ? descriptionTr : descriptionEn;
  }
}

const List<ProfileBadge> allProfileBadges = [
  ProfileBadge(
    id: 'novice',
    nameTr: 'Acemi',
    nameEn: 'Novice',
    color: Color(0xFF8E2DE2),
    glowColor: Color(0xFF4A00E0),
    textColor: Colors.white,
    descriptionTr: 'Koleksiyonda en az 3 bebek olması.',
    descriptionEn: 'At least 3 dolls in your collection.',
    dollRequirement: 3,
  ),
  ProfileBadge(
    id: 'collector',
    nameTr: 'Koleksiyoner',
    nameEn: 'Collector',
    color: Color(0xFF00F2FE),
    glowColor: Color(0xFF4FACFE),
    textColor: Colors.black87,
    descriptionTr: 'Koleksiyonda en az 15 bebek olması.',
    descriptionEn: 'At least 15 dolls in your collection.',
    dollRequirement: 15,
  ),
  ProfileBadge(
    id: 'curator',
    nameTr: 'Küratör',
    nameEn: 'Curator',
    color: Color(0xFFF000FF),
    glowColor: Color(0xFF7B00FF),
    textColor: Colors.white,
    descriptionTr: 'Koleksiyonda en az 40 bebek olması.',
    descriptionEn: 'At least 40 dolls in your collection.',
    dollRequirement: 40,
  ),
  ProfileBadge(
    id: 'museum_director',
    nameTr: 'Müze Müdürü',
    nameEn: 'Museum Director',
    color: Color(0xFFEC008C),
    glowColor: Color(0xFFFC6767),
    textColor: Colors.white,
    descriptionTr: 'Koleksiyonda en az 70 bebek olması.',
    descriptionEn: 'At least 70 dolls in your collection.',
    dollRequirement: 70,
  ),
  ProfileBadge(
    id: 'box_lover',
    nameTr: 'Kutucu',
    nameEn: 'Box Lover',
    color: Color(0xFF00FFCC),
    glowColor: Color(0xFF00B38F),
    textColor: Colors.black87,
    descriptionTr: 'En az 5 adet Kutulu (Boxed) bebek olması.',
    descriptionEn: 'At least 5 Mint-In-Box (Boxed) dolls.',
    boxedRequirement: 5,
  ),
  ProfileBadge(
    id: 'restorer',
    nameTr: 'Yenilikçi',
    nameEn: 'Restorer',
    color: Color(0xFF11998E),
    glowColor: Color(0xFF38EF7D),
    textColor: Colors.white,
    descriptionTr: 'En az 5 adet Açılmış/Eksiksiz bebek olması.',
    descriptionEn: 'At least 5 Unboxed/Complete dolls.',
  ),
  ProfileBadge(
    id: 'pro_member',
    nameTr: 'Pro Üye',
    nameEn: 'Pro Member',
    color: Color(0xFFEC008C),
    glowColor: Color(0xFFFF007F),
    textColor: Colors.white,
    descriptionTr: 'Aktif DollDex Pro Üyesi olmak.',
    descriptionEn: 'Have an active DollDex Pro subscription.',
    isProOnly: true,
  ),
  ProfileBadge(
    id: 'doldex_vip',
    nameTr: 'Doldex VIP',
    nameEn: 'Doldex VIP',
    color: Color(0xFFFFD700),
    glowColor: Color(0xFFFFAA00),
    textColor: Colors.black87,
    descriptionTr: 'Pro Üyelik + Koleksiyonda 25 bebek olması.',
    descriptionEn: 'Pro member with at least 25 dolls.',
    isProOnly: true,
    dollRequirement: 25,
  ),
  ProfileBadge(
    id: 'queen',
    nameTr: 'Kraliçe',
    nameEn: 'Queen',
    color: Color(0xFFFF0055),
    glowColor: Color(0xFFFF00CC),
    textColor: Colors.white,
    descriptionTr: '1000 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 1000 Coins.',
    coinsPrice: 1000,
  ),
  ProfileBadge(
    id: 'princess',
    nameTr: 'Prenses',
    nameEn: 'Princess',
    color: Color(0xFF00E5FF),
    glowColor: Color(0xFF0077FF),
    textColor: Colors.black87,
    descriptionTr: '1000 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 1000 Coins.',
    coinsPrice: 1000,
  ),
  ProfileBadge(
    id: 'legendary',
    nameTr: 'Efsanevi',
    nameEn: 'Legendary',
    color: Color(0xFFFFCC00),
    glowColor: Color(0xFFFF4500),
    textColor: Colors.black87,
    descriptionTr: '1000 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 1000 Coins.',
    coinsPrice: 1000,
  ),
  ProfileBadge(
    id: 'star',
    nameTr: 'Yıldız',
    nameEn: 'Star',
    color: Color(0xFF1E1E1E),
    glowColor: Color(0xFF8338EC),
    textColor: Colors.white,
    descriptionTr: '5+ Yorum yapmış olmak veya 1000 Jeton.',
    descriptionEn: '5+ comments posted or 1000 Coins.',
    coinsPrice: 1000,
    commentsRequirement: 5,
  ),
  ProfileBadge(
    id: 'creepover',
    nameTr: 'Pijama Partisi',
    nameEn: 'Creepover Party',
    color: Color(0xFF9D4EDD),
    glowColor: Color(0xFFC77DFF),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'dawn_of_dance',
    nameTr: 'Dansın Şafağı',
    nameEn: 'Dawn of the Dance',
    color: Color(0xFFFF007F),
    glowColor: Color(0xFFFF52AF),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'sweet_1600',
    nameTr: 'Tatlı 1600',
    nameEn: 'Sweet 1600',
    color: Color(0xFFFF0055),
    glowColor: Color(0xFFFF66A3),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'ghouls_rule',
    nameTr: 'Ucubeler Kuralı',
    nameEn: 'Ghouls Rule',
    color: Color(0xFFFF5500),
    glowColor: Color(0xFFFF9933),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'skull_shores',
    nameTr: 'Kafatası Sahili',
    nameEn: 'Skull Shores',
    color: Color(0xFF00FFCC),
    glowColor: Color(0xFF33FFDD),
    textColor: Colors.black87,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'thirteen_wishes',
    nameTr: '13 Dilek',
    nameEn: '13 Wishes',
    color: Color(0xFFFFB703),
    glowColor: Color(0xFFFB8500),
    textColor: Colors.black87,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'frights_camera',
    nameTr: 'Işık Kamera Dehşet',
    nameEn: 'Frights, Camera, Action!',
    color: Color(0xFF7209B7),
    glowColor: Color(0xFFB5179E),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'freaky_fusion',
    nameTr: 'Acayip Karışım',
    nameEn: 'Freaky Fusion',
    color: Color(0xFF4CC9F0),
    glowColor: Color(0xFF4895EF),
    textColor: Colors.black87,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'haunted_ghouls',
    nameTr: 'Hayalet Okulu',
    nameEn: 'Haunted',
    color: Color(0xFFE2E2E2),
    glowColor: Color(0xFFE2E2E2),
    textColor: Colors.black87,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'boo_york',
    nameTr: 'Acayip York',
    nameEn: 'Boo York',
    color: Color(0xFF3F37C9),
    glowColor: Color(0xFF4361EE),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'great_scarrier',
    nameTr: 'Büyük Resif',
    nameEn: 'Great Scarrier Reef',
    color: Color(0xFF073B4C),
    glowColor: Color(0xFF118AB2),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
  ProfileBadge(
    id: 'skulltimate',
    nameTr: 'Kilitli Sırlar',
    nameEn: 'Skulltimate Secrets',
    color: Color(0xFFEF476F),
    glowColor: Color(0xFFFF8FA3),
    textColor: Colors.white,
    descriptionTr: '100 Jeton karşılığında satın alınabilir.',
    descriptionEn: 'Available for purchase with 100 Coins.',
    coinsPrice: 100,
  ),
];

bool checkBadgeRequirement(
  ProfileBadge badge,
  ProfileSetupStatus status,
  List<CollectionEntry> collection,
  int commentCount,
) {
  if (badge.id == 'novice') {
    return collection.length >= 3;
  }
  if (badge.id == 'collector') {
    return collection.length >= 15;
  }
  if (badge.id == 'curator') {
    return collection.length >= 40;
  }
  if (badge.id == 'museum_director') {
    return collection.length >= 70;
  }
  if (badge.id == 'box_lover') {
    final boxed = collection
        .where((e) => e.condition == CollectionCondition.boxed)
        .length;
    return boxed >= 5;
  }
  if (badge.id == 'restorer') {
    final opened = collection
        .where((e) =>
            e.condition == CollectionCondition.unboxed ||
            e.condition == CollectionCondition.complete)
        .length;
    return opened >= 5;
  }
  if (badge.id == 'pro_member') {
    return status.isPro;
  }
  if (badge.id == 'doldex_vip') {
    return status.isPro && collection.length >= 25;
  }
  if (badge.id == 'queen' ||
      badge.id == 'princess' ||
      badge.id == 'creepover' ||
      badge.id == 'dawn_of_dance' ||
      badge.id == 'sweet_1600' ||
      badge.id == 'ghouls_rule' ||
      badge.id == 'skull_shores' ||
      badge.id == 'thirteen_wishes' ||
      badge.id == 'frights_camera' ||
      badge.id == 'freaky_fusion' ||
      badge.id == 'haunted_ghouls' ||
      badge.id == 'boo_york' ||
      badge.id == 'great_scarrier' ||
      badge.id == 'skulltimate') {
    return true;
  }
  if (badge.id == 'star') {
    return commentCount >= 5;
  }
  return false;
}

class ProfileBadgeWidget extends StatelessWidget {
  const ProfileBadgeWidget({required this.badgeId, this.size = 9, super.key});

  final String badgeId;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (badgeId.isEmpty) return const SizedBox.shrink();
    final badge = allProfileBadges.firstWhere(
      (b) => b.id == badgeId,
      orElse: () => allProfileBadges.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badge.textColor.withOpacity(0.3), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: badge.glowColor.withOpacity(0.6),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        badge.name(context).toUpperCase(),
        style: TextStyle(
          color: badge.textColor,
          fontSize: size,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

void showAnnouncementModalDetail(BuildContext context,
    {required String title, required String body}) {
  final theme = Theme.of(context);
  final primaryColor = theme.colorScheme.primary;
  final secondaryColor = theme.colorScheme.secondary;
  final outlineColor = theme.colorScheme.outline;
  final surfaceColor = theme.colorScheme.surface;
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: outlineColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: outlineColor.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: primaryColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr ? 'Duyuru Detayı' : 'Announcement Detail',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          color: primaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: theme.iconTheme.color?.withOpacity(0.7) ??
                          Colors.black54,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer / Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  style: theme.elevatedButtonTheme.style ??
                      ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    tr ? 'Kapat' : 'Close',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

void showNotificationsModal(BuildContext context, {int? initialTab}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return NotificationsModal(initialTab: initialTab);
    },
  );
}

class NotificationsModal extends StatefulWidget {
  final int? initialTab;
  const NotificationsModal({super.key, this.initialTab});

  @override
  State<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<NotificationsModal> {
  late int _activeTab;
  static double _savedScrollOffset = 0.0;
  static int _savedActiveTab = 0;
  static bool _shouldRestoreScroll = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? _savedActiveTab;
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final userId = user?.uid ?? 'local-user';
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_shouldRestoreScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (scrollController.hasClients) {
                try {
                  scrollController.jumpTo(_savedScrollOffset);
                } catch (_) {}
              }
              _shouldRestoreScroll = false;
            });
          });
        }

        return StreamBuilder<List<AppNotification>>(
          stream: notificationRepository.watchForUser(userId),
          builder: (context, snapshot) {
            final theme = Theme.of(context);
            final primaryColor = theme.colorScheme.primary;
            final secondaryColor = theme.colorScheme.secondary;
            final panelAltColor = theme.colorScheme.secondaryContainer;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              );
            }

            final notifications = snapshot.data ?? [];
            final announcements = notifications
                .where((n) => n.deepLink.startsWith('/announcement'))
                .toList();
            final regularNotifications = notifications
                .where((n) => !n.deepLink.startsWith('/announcement'))
                .toList();

            return NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification.metrics.axis == Axis.vertical) {
                  _savedScrollOffset = scrollNotification.metrics.pixels;
                }
                return false;
              },
              child: ListView(
                key: const PageStorageKey('notifications_modal_outer_scroll'),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr ? 'Bildirimler' : 'Notifications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                      if (userId != 'local-user' &&
                          notifications.isNotEmpty &&
                          _activeTab != 1)
                        TextButton.icon(
                          icon: Icon(Icons.done_all_rounded,
                              size: 16, color: primaryColor),
                          label: Text(
                            tr ? 'Tümünü Oku' : 'Read All',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            await notificationRepository.markAllRead(userId);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_activeTab != 1 && notifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: panelAltColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: primaryColor,
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
                                color: secondaryColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Sekmeler
                  Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          label: tr
                              ? 'Bildirimler (${regularNotifications.length})'
                              : 'Notifications (${regularNotifications.length})',
                          isActive: _activeTab == 0,
                          onTap: () => setState(() {
                            _activeTab = 0;
                            _savedActiveTab = 0;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTabButton(
                          label: tr ? 'Akış' : 'Activity Feed',
                          isActive: _activeTab == 1,
                          onTap: () => setState(() {
                            _activeTab = 1;
                            _savedActiveTab = 1;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTabButton(
                          label: tr
                              ? 'Duyurular (${announcements.length})'
                              : 'Announcements (${announcements.length})',
                          isActive: _activeTab == 2,
                          onTap: () => setState(() {
                            _activeTab = 2;
                            _savedActiveTab = 2;
                          }),
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
                  else if (_activeTab == 1)
                    SocialFeedTab(
                      userId: userId,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onNavigate: (route) {
                        _savedActiveTab = 1;
                        _shouldRestoreScroll = true;
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        rootContext.push(route).then((_) {
                          showNotificationsModal(rootContext, initialTab: 1);
                        });
                      },
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    final outlineColor = theme.colorScheme.outline;
    final surfaceColor = theme.colorScheme.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive ? primaryColor.withOpacity(0.15) : surfaceColor,
          border: Border.all(
            color: isActive ? primaryColor : outlineColor.withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? primaryColor : secondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    List<AppNotification> list, {
    required bool canDelete,
    required String userId,
    required bool isTr,
  }) {
    if (list.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            isTr
                ? 'Bu kategoride bildirim bulunmuyor.'
                : 'No notifications in this category.',
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.secondary.withOpacity(0.7)),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    final outlineColor = theme.colorScheme.outline;
    final surfaceColor = theme.colorScheme.surface;
    final panelAltColor = theme.colorScheme.secondaryContainer;
    final errorColor = theme.colorScheme.error;

    return ListView.builder(
      key: PageStorageKey(
          'notifications_list_${canDelete ? "regular" : "announcements"}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final notification = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Dismissible(
            key: Key(
                'modal-notification-${notification.id}-${notification.isRead}'),
            direction: canDelete
                ? DismissDirection.horizontal
                : DismissDirection.startToEnd,
            background: Container(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: Icon(Icons.mark_email_read_rounded,
                  color: primaryColor, size: 18),
            ),
            secondaryBackground: canDelete
                ? Container(
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete_forever_rounded,
                        color: errorColor, size: 18),
                  )
                : null,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await notificationRepository.markRead(notification.id);
                return false;
              } else if (direction == DismissDirection.endToStart &&
                  canDelete) {
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
                      : primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              color: notification.isRead ? surfaceColor : panelAltColor,
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                onTap: () async {
                  final route = notification.deepLink;
                  if (!notification.isRead) {
                    notificationRepository.markRead(notification.id);
                  }
                  if (route.isNotEmpty) {
                    if (route.startsWith('/announcement')) {
                      showAnnouncementModalDetail(
                        context,
                        title: notification.title,
                        body: notification.body,
                      );
                    } else {
                      _savedActiveTab = _activeTab;
                      _shouldRestoreScroll = true;
                      final rootContext =
                          Navigator.of(context, rootNavigator: true).context;
                      Navigator.of(context).pop();
                      rootContext.push(route).then((_) {
                        showNotificationsModal(rootContext,
                            initialTab: _savedActiveTab);
                      });
                    }
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: notification.isRead
                        ? outlineColor.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    notificationTypeIcon(notification.type),
                    color: notification.isRead ? secondaryColor : primaryColor,
                    size: 16,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                    color: notification.isRead
                        ? secondaryColor
                        : theme.textTheme.bodyLarge?.color,
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
                        color: secondaryColor
                            .withOpacity(notification.isRead ? 0.7 : 1.0),
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatMessageTime(notification.createdAt!),
                        style: TextStyle(
                          fontSize: 9,
                          color: secondaryColor.withOpacity(0.5),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GothicCampaignCountdown extends StatefulWidget {
  final DateTime endTime;
  const GothicCampaignCountdown({required this.endTime, super.key});

  @override
  State<GothicCampaignCountdown> createState() =>
      _GothicCampaignCountdownState();
}

class _GothicCampaignCountdownState extends State<GothicCampaignCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  void _calculateRemaining() {
    _remaining = widget.endTime.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _buildTimeBox(
      String value, String label, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF160E26) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    final accentColor = const Color(0xFFFFD700);

    if (_remaining.inSeconds == 0) {
      return Text(
        tr ? 'Kampanya Sona Erdi!' : 'Campaign Ended!',
        style: GoogleFonts.outfit(
          color: Colors.redAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final days = _remaining.inDays.toString().padLeft(2, '0');
    final hours = (_remaining.inHours % 24).toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeBox(days, tr ? 'Gün' : 'Day', accentColor, isDark),
        const SizedBox(width: 8),
        _buildTimeBox(hours, tr ? 'Saat' : 'Hour', accentColor, isDark),
        const SizedBox(width: 8),
        _buildTimeBox(minutes, tr ? 'Dk' : 'Min', accentColor, isDark),
        const SizedBox(width: 8),
        _buildTimeBox(seconds, tr ? 'Sn' : 'Sec', accentColor, isDark),
      ],
    );
  }
}

class PriceOptionCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool isSelected;

  const PriceOptionCard({
    required this.title,
    required this.price,
    required this.subtitle,
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = const Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B0F2B) : const Color(0xFFFBF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA)),
          width: isSelected ? 2.0 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: GoogleFonts.outfit(
              color: isDark ? accentColor : primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
