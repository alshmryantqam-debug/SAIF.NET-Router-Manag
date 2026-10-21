import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated 3D wireframe sphere. This is a visual network-core illustration;
/// it does not represent live router telemetry.
class Cyber3DSphere extends StatefulWidget {
  const Cyber3DSphere({
    super.key,
    this.color = const Color(0xFF00E5FF),
  });

  final Color color;

  @override
  State<Cyber3DSphere> createState() => _Cyber3DSphereState();
}

class _Cyber3DSphereState extends State<Cyber3DSphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _SpherePainter(
            animationValue: _controller.value,
            color: widget.color,
          ),
          size: const Size(250, 250),
        ),
      ),
    );
  }
}

class _SpherePainter extends CustomPainter {
  const _SpherePainter({
    required this.animationValue,
    required this.color,
  });

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.43;
    final rotationY = animationValue * 2 * math.pi;
    final rotationX = animationValue * math.pi;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius * 0.88, glowPaint);

    final backPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final frontPaint = Paint()
      ..color = color.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    Offset project(double lat, double lon) {
      final x = math.cos(lat) * math.cos(lon + rotationY);
      final y = math.sin(lat);
      final z = math.cos(lat) * math.sin(lon + rotationY);
      final yRot = y * math.cos(rotationX) - z * math.sin(rotationX);
      final zRot = y * math.sin(rotationX) + z * math.cos(rotationX);
      final perspective = 2.5 / (2.5 - zRot * 0.42);
      return Offset(
        center.dx + x * perspective * radius,
        center.dy + yRot * perspective * radius,
      );
    }

    // Longitude and latitude paths use perspective projection. Back-facing
    // segments are dimmed for depth rather than being presented as live data.
    for (int i = 1; i < 10; i++) {
      final lat = -math.pi / 2 + math.pi * i / 10;
      final path = Path();
      for (int j = 0; j <= 96; j++) {
        final point = project(lat, 2 * math.pi * j / 96);
        if (j == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, backPaint);
      canvas.drawPath(path, frontPaint);
    }

    for (int i = 0; i < 16; i++) {
      final lon = 2 * math.pi * i / 16;
      final path = Path();
      for (int j = 0; j <= 96; j++) {
        final lat = -math.pi / 2 + math.pi * j / 96;
        final point = project(lat, lon);
        if (j == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, backPaint);
      canvas.drawPath(path, frontPaint);
    }

    canvas.drawCircle(
      center,
      radius * 0.09,
      Paint()
        ..color = color.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, radius * 0.045, highlightPaint);

    // Small orbital nodes add depth to the core visualization.
    for (int i = 0; i < 8; i++) {
      final angle = animationValue * 2 * math.pi + i * math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * radius * 1.08,
        center.dy + math.sin(angle * 1.7) * radius * 0.72,
      );
      canvas.drawCircle(point, 2.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SpherePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}
