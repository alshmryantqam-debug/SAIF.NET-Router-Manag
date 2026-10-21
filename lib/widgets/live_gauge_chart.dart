import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated, custom-painted gauge. percentage is normalized to 0.0–1.0.
class LiveGaugeChart extends StatelessWidget {
  const LiveGaugeChart({
    super.key,
    required this.title,
    required this.percentage,
    required this.activeColor,
    this.isOffline = false,
    this.size = 104,
  });

  final String title;
  final double percentage;
  final Color activeColor;
  final bool isOffline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = percentage.isFinite ? percentage.clamp(0.0, 1.0) : 0.0;
    final color = isOffline ? const Color(0xFFFF4D67) : activeColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isOffline ? .35 : .12)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(.06), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) => CustomPaint(
                painter: _GaugePainter(
                  percentage: animatedValue,
                  activeColor: color,
                ),
                child: Center(
                  child: Text(
                    isOffline ? '—' : '${(animatedValue * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isOffline) ...[
            const SizedBox(height: 8),
            const Text('غير متصل', style: TextStyle(color: Color(0xFFFF4D67), fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.percentage, required this.activeColor});

  final double percentage;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final stroke = shortestSide * .105;
    final radius = (shortestSide - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final background = Paint()
      ..color = Colors.white.withOpacity(.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, background);

    final foreground = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [activeColor.withOpacity(.45), activeColor],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * percentage.clamp(0.0, 1.0),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.activeColor != activeColor;
}
