import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated geometric core indicator. It visualizes the selected engine state;
/// it does not itself change RouterOS configuration.
class CyberHexagonCore extends StatefulWidget {
  const CyberHexagonCore({super.key, required this.isActive});

  final bool isActive;

  @override
  State<CyberHexagonCore> createState() => _CyberHexagonCoreState();
}

class _CyberHexagonCoreState extends State<CyberHexagonCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF657A);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = math.sin(_controller.value * 2 * math.pi);
        return SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108 + pulse * 16,
                height: 108 + pulse * 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.24),
                      blurRadius: 34,
                      spreadRadius: 7,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(148, 148),
                  painter: _HexagonPainter(
                    color: color,
                    strokeWidth: 2.8,
                  ),
                ),
              ),
              Transform.rotate(
                angle: -_controller.value * 3 * math.pi,
                child: CustomPaint(
                  size: const Size(112, 112),
                  painter: _HexagonPainter(
                    color: color.withOpacity(0.58),
                    strokeWidth: 1.3,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(58, 58),
                painter: _HexagonPainter(
                  color: color.withOpacity(0.18),
                  filled: true,
                ),
              ),
              Icon(
                widget.isActive
                    ? Icons.memory_rounded
                    : Icons.gpp_bad_rounded,
                color: color,
                size: 32,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter({
    required this.color,
    this.filled = false,
    this.strokeWidth = 2,
  });

  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - strokeWidth;
    final path = Path();

    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.filled != filled ||
      oldDelegate.strokeWidth != strokeWidth;
}
