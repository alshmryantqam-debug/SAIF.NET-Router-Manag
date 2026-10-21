import 'dart:math' as math;

import 'package:flutter/material.dart';

class CyberBtestReactor extends StatefulWidget {
  const CyberBtestReactor({
    super.key,
    required this.rxSpeed,
    required this.txSpeed,
    required this.isTesting,
  });

  final double rxSpeed;
  final double txSpeed;
  final bool isTesting;

  @override
  State<CyberBtestReactor> createState() => _CyberBtestReactorState();
}

class _CyberBtestReactorState extends State<CyberBtestReactor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isTesting) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant CyberBtestReactor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTesting && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isTesting && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _CyberBtestPainter(
            phase: _controller.value,
            rxSpeed: widget.rxSpeed,
            txSpeed: widget.txSpeed,
            isTesting: widget.isTesting,
          ),
        ),
      ),
    );
  }
}

class _CyberBtestPainter extends CustomPainter {
  const _CyberBtestPainter({
    required this.phase,
    required this.rxSpeed,
    required this.txSpeed,
    required this.isTesting,
  });

  final double phase;
  final double rxSpeed;
  final double txSpeed;
  final bool isTesting;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rxColor = const Color(0xFF00D9FF);
    final txColor = const Color(0xFFE040FB);
    final rxRatio = (rxSpeed / 1000).clamp(0.0, 1.0).toDouble();
    final txRatio = (txSpeed / 1000).clamp(0.0, 1.0).toDouble();
    final rect = Rect.fromCircle(center: center, radius: size.shortestSide / 2 - 18);

    // Tactical background rings and fine graduations.
    for (var ring = 0; ring < 4; ring++) {
      final radius = 34.0 + ring * 25;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withOpacity(ring == 3 ? .11 : .045)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < 48; i++) {
      final angle = (math.pi * 2 * i / 48) - math.pi / 2;
      final outer = size.shortestSide / 2 - 5;
      final inner = outer - (i % 4 == 0 ? 10 : 4);
      final p1 = center + Offset(math.cos(angle) * inner, math.sin(angle) * inner);
      final p2 = center + Offset(math.cos(angle) * outer, math.sin(angle) * outer);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white.withOpacity(i % 4 == 0 ? .35 : .13)
          ..strokeWidth = i % 4 == 0 ? 1.5 : 1,
      );
    }

    final startAngle = math.pi * .75;
    final sweep = math.pi * 1.5;
    final rxRadius = size.shortestSide / 2 - 23;
    final txRadius = size.shortestSide / 2 - 48;

    void drawMeter(double radius, double ratio, Color color, double width) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        arcRect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = Colors.white.withOpacity(.075)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
      if (ratio <= 0) return;
      if (isTesting) {
        canvas.drawArc(
          arcRect,
          startAngle,
          sweep * ratio,
          false,
          Paint()
            ..color = color.withOpacity(.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + 7
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + ratio * 9),
        );
      }
      canvas.drawArc(
        arcRect,
        startAngle,
        sweep * ratio,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    drawMeter(rxRadius, rxRatio, rxColor, 13);
    drawMeter(txRadius, txRatio, txColor, 10);

    if (isTesting) {
      final pulse = 31 + 4 * math.sin(phase * math.pi * 2);
      canvas.drawCircle(
        center,
        pulse,
        Paint()
          ..color = rxColor.withOpacity(.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      final sweepAngle = phase * math.pi * 2;
      final end = center + Offset(math.cos(sweepAngle) * rxRadius, math.sin(sweepAngle) * rxRadius);
      canvas.drawCircle(end, 3.5, Paint()..color = Colors.white);
    }

    canvas.drawCircle(center, 28, Paint()..color = const Color(0xFF090D19));
    canvas.drawCircle(
      center,
      28,
      Paint()
        ..color = rxColor.withOpacity(.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _text(canvas, 'قياس', center.translate(0, -8), 11, Colors.white, FontWeight.w900, center: true);
    _text(canvas, isTesting ? 'جارٍ الفحص' : 'جاهز', center.translate(0, 8), 8, rxColor, FontWeight.bold, center: true);

    _text(canvas, 'استقبال', center.translate(-70, 15), 10, rxColor, FontWeight.bold, center: true);
    _text(canvas, 'إرسال', center.translate(70, 15), 10, txColor, FontWeight.bold, center: true);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset position,
    double size,
    Color color,
    FontWeight weight, {
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          shadows: [Shadow(color: color.withOpacity(.6), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    painter.paint(canvas, center ? position.translate(-painter.width / 2, -painter.height / 2) : position);
  }

  @override
  bool shouldRepaint(covariant _CyberBtestPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.rxSpeed != rxSpeed ||
      oldDelegate.txSpeed != txSpeed ||
      oldDelegate.isTesting != isTesting;
}
