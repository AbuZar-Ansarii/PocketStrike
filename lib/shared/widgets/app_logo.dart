import 'package:flutter/material.dart';

/// Inspired Robot Head AI Logo for PocketStrike.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 32,
    this.color,
    this.eyeColor = Colors.white,
    this.showGlow = true,
  });

  final double size;
  final Color? color;
  final Color eyeColor;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            size: Size(size, size),
            painter: _RobotLogoPainter(
              color: primaryColor,
              eyeColor: eyeColor,
              showGlow: showGlow,
            ),
          ),
        ),
      ),
    );
  }
}

class _RobotLogoPainter extends CustomPainter {
  _RobotLogoPainter({
    required this.color,
    required this.eyeColor,
    required this.showGlow,
  });

  final Color color;
  final Color eyeColor;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      // Top Antenna glow
      final antennaRect = Rect.fromCenter(
        center: Offset(width * 0.5, height * 0.12),
        width: width * 0.14,
        height: height * 0.18,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(antennaRect, Radius.circular(width * 0.07)),
        glowPaint,
      );

      // Main Head glow
      final headRect = Rect.fromCenter(
        center: Offset(width * 0.5, height * 0.54),
        width: width * 0.64,
        height: height * 0.58,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(headRect, Radius.circular(width * 0.18)),
        glowPaint,
      );
    }

    // 1. Top Antenna Node
    final antennaRect = Rect.fromCenter(
      center: Offset(width * 0.5, height * 0.14),
      width: width * 0.13,
      height: height * 0.18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(antennaRect, Radius.circular(width * 0.065)),
      paint,
    );

    // 2. Left Ear Cap
    final leftEarRect = Rect.fromCenter(
      center: Offset(width * 0.12, height * 0.54),
      width: width * 0.12,
      height: height * 0.32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftEarRect, Radius.circular(width * 0.05)),
      paint,
    );

    // 3. Right Ear Cap
    final rightEarRect = Rect.fromCenter(
      center: Offset(width * 0.88, height * 0.54),
      width: width * 0.12,
      height: height * 0.32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightEarRect, Radius.circular(width * 0.05)),
      paint,
    );

    // 4. Main Robot Head Box
    final headRect = Rect.fromCenter(
      center: Offset(width * 0.5, height * 0.54),
      width: width * 0.64,
      height: height * 0.58,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(width * 0.18)),
      paint,
    );

    // 5. Circular Glowing Eyes
    final eyePaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill;

    final eyeRadius = width * 0.09;
    final leftEyeCenter = Offset(width * 0.38, height * 0.54);
    final rightEyeCenter = Offset(width * 0.62, height * 0.54);

    canvas.drawCircle(leftEyeCenter, eyeRadius, eyePaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _RobotLogoPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.eyeColor != eyeColor ||
        oldDelegate.showGlow != showGlow;
  }
}
