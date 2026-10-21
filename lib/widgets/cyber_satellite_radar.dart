import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated uplink illustration. The color reflects the connection state
/// supplied by the caller; this widget does not probe a satellite or router.
class CyberSatelliteRadar extends StatefulWidget {
  const CyberSatelliteRadar({
    super.key,
    this.isConnected = false,
  });

  final bool isConnected;

  @override
  State<CyberSatelliteRadar> createState() => _CyberSatelliteRadarState();
}

class _CyberSatelliteRadarState extends State<CyberSatelliteRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF5252);

    return Semantics(
      label: widget.isConnected
          ? 'رسم توضيحي لوصلة مدارية متصلة'
          : 'رسم توضيحي لوصلة مدارية غير متصلة',
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _SatellitePainter(
              animationValue: _controller.value,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SatellitePainter extends CustomPainter {
  const _SatellitePainter({
    required this.animationValue,
    required this.color,
  });

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 42);
    final signalOrigin = center.translate(0, -22);

    // Soft tactical grid.
    final gridPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 0.7;
    for (double x = 10; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), gridPaint);
    }
    for (double y = 10; y < size.height; y += 20) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
    }

    // Uplink arcs expand upward from the dish.
    for (int i = 0; i < 3; i++) {
      final phase = (animationValue + i / 3) % 1.0;
      final radius = 26 + phase * 100;
      final opacity = (1.0 - phase) * 0.7;
      final wavePaint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawArc(
        Rect.fromCircle(center: signalOrigin, radius: radius),
        -math.pi * 0.78,
        -math.pi * 0.44,
        false,
        wavePaint,
      );
    }

    final dishPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dishPath = Path()
      ..arcTo(
        Rect.fromCircle(center: center.translate(0, -30), radius: 40),
        0,
        -math.pi,
        true,
      );
    canvas.drawPath(dishPath, dishPaint);
    canvas.drawLine(center.translate(0, -10), center.translate(0, 20), dishPaint);
    canvas.drawLine(center.translate(-20, 20), center.translate(20, 20), dishPaint);

    canvas.drawCircle(
      signalOrigin,
      9,
      Paint()
        ..color = color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(signalOrigin, 5, Paint()..color = color);
    canvas.drawCircle(signalOrigin, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SatellitePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}
