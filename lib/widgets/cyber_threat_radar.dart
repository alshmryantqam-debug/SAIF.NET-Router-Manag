import 'dart:math' as math;

import 'package:flutter/material.dart';

class CyberThreatRadar extends StatefulWidget {
  final bool hasThreat;

  const CyberThreatRadar({super.key, this.hasThreat = false});

  @override
  State<CyberThreatRadar> createState() => _CyberThreatRadarState();
}

class _CyberThreatRadarState extends State<CyberThreatRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.hasThreat ? 800 : 3000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant CyberThreatRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasThreat != widget.hasThreat) {
      _controller.duration =
          Duration(milliseconds: widget.hasThreat ? 800 : 3000);
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 230,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ThreatRadarPainter(
            phase: _controller.value,
            hasThreat: widget.hasThreat,
          ),
        ),
      ),
    );
  }
}

class _ThreatRadarPainter extends CustomPainter {
  final double phase;
  final bool hasThreat;

  const _ThreatRadarPainter({required this.phase, required this.hasThreat});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;
    final signal = hasThreat ? const Color(0xFFFF414D) : const Color(0xFF27C9FF);
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final background = Paint()
      ..shader = RadialGradient(
        colors: [
          signal.withOpacity(0.12),
          const Color(0xFF071526).withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, background);

    final grid = Paint()
      ..color = signal.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final factor in [1.0, 0.75, 0.5, 0.25]) {
      canvas.drawCircle(center, radius * factor, grid);
    }
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), grid);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), grid);
    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy - radius * 0.7),
      Offset(center.dx + radius * 0.7, center.dy + radius * 0.7),
      grid,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy + radius * 0.7),
      Offset(center.dx + radius * 0.7, center.dy - radius * 0.7),
      grid,
    );

    final angle = phase * math.pi * 2;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: angle - math.pi / 2,
        endAngle: angle,
        colors: [
          Colors.transparent,
          signal.withOpacity(0.02),
          signal.withOpacity(0.42),
        ],
      ).createShader(bounds);
    canvas.drawArc(bounds, angle - math.pi / 2, math.pi / 2, true, sweep);

    final beam = Paint()
      ..color = signal.withOpacity(0.8)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      center,
      Offset(center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius),
      beam,
    );
    canvas.drawCircle(center, 4, Paint()..color = signal);

    if (hasThreat) {
      final target = Offset(
        center.dx + math.cos(math.pi / 4) * radius * 0.68,
        center.dy + math.sin(math.pi / 4) * radius * 0.68,
      );
      final pulse = (math.sin(phase * math.pi * 8) + 1) / 2;
      canvas.drawCircle(
        target,
        7 + pulse * 7,
        Paint()..color = signal.withOpacity(0.18 + pulse * 0.35),
      );
      canvas.drawCircle(target, 4, Paint()..color = Colors.white);
      canvas.drawLine(
        center,
        target,
        Paint()
          ..color = signal.withOpacity(0.9)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThreatRadarPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.hasThreat != hasThreat;
}
