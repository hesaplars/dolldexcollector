import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/app_language.dart';
import '../core/web_image_helper.dart';

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
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.dark,
        primary: teal,
        secondary: berry,
        surface: darkPaper,
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
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkLine, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkLine, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkPanel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: darkLine, width: 1.5),
        ),
        dragHandleColor: darkLine,
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
          foregroundColor: darkInk,
          side: const BorderSide(color: darkLine, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
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
    _drawCornerBat(canvas, const Offset(16, 16), batPaint); // Sol Üst
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

class _GothicAdBannerHorizontalState extends State<GothicAdBannerHorizontal> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171026) : const Color(0xFFF5EBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 60),
            painter: IvyBorderPainter(
              color: isDark ? const Color(0xFFEC008C).withOpacity(0.15) : const Color(0xFFEC008C).withOpacity(0.2),
            ),
          ),
          Center(
            child: Text(
              'ADVERTISEMENT',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Cinzel',
                letterSpacing: 4,
                color: isDark ? Colors.white24 : Colors.black26,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                          color: isDark ? const Color(0xFF160E22) : const Color(0xFFFAF6FC),
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
                            buildNeonIcon(context, Icons.info_outline_rounded, size: 20),
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

Widget buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
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

Widget buildGothicNeonIconButton({
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
    child: buildNeonIcon(context, icon, size: size),
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

Widget buildAvatarHelper(String avatarId, String frameColor, {double size = 40}) {
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

void showPhotoGalleryDialog(BuildContext context, List<String> imageUrls, int initialIndex) {
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
              onTap: () => showPhotoGalleryDialog(context, widget.imageUrls, index),
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

Widget buildCoverPhoto(BuildContext context, String? coverId, {required bool isPro}) {
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
                      color: const Color(0xFFEC008C).withOpacity(0.8),
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
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: buildAvatarHelper(
        avatarId,
        selected ? frameColor : '',
        size: 56,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
