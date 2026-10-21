import 'dart:math' as math;

import 'package:flutter/material.dart';

/// بيانات خط إنترنت؛ تُملأ لاحقاً من مزود اتصال الراوتر.
class WanLine {
  final String name;
  final bool isOnline;
  final Color color;
  final double angle;

  const WanLine({
    required this.name,
    required this.isOnline,
    required this.color,
    required this.angle,
  });
}

/// مفاعل بصري متحرك لعرض مسارات خطوط الإنترنت نحو مركز الدمج.
class CyberPccReactor extends StatefulWidget {
  final List<WanLine> wans;

  const CyberPccReactor({Key? key, required this.wans}) : super(key: key);

  @override
  State<CyberPccReactor> createState() => _CyberPccReactorState();
}

class _CyberPccReactorState extends State<CyberPccReactor>
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
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ReactorPainter(
            animationValue: _controller.value,
            wans: widget.wans,
          ),
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  final double animationValue;
  final List<WanLine> wans;

  const _ReactorPainter({
    required this.animationValue,
    required this.wans,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = 37.0;
    final maxRadius = math.min(size.width * 0.42, size.height * 0.43).toDouble();

    // شبكة خلفية خافتة تمنح المفاعل عمقاً بصرياً.
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.07)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final wan in wans) {
      final startPos = Offset(
        center.dx + math.cos(wan.angle) * maxRadius,
        center.dy + math.sin(wan.angle) * maxRadius,
      );
      final lineColor =
          wan.isOnline ? wan.color : const Color(0xFFFF5252);
      final controlPoint = Offset(
        (startPos.dx + center.dx) / 2,
        startPos.dy,
      );
      final path = Path()
        ..moveTo(startPos.dx, startPos.dy)
        ..quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          center.dx,
          center.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withOpacity(wan.isOnline ? 0.42 : 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = wan.isOnline ? 2.6 : 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      if (wan.isOnline) {
        for (var i = 0; i < 3; i++) {
          final t = (animationValue + i / 3) % 1.0;
          final inverseT = 1.0 - t;
          final x = (inverseT * inverseT * startPos.dx +
                  2 * inverseT * t * controlPoint.dx +
                  t * t * center.dx)
              .toDouble();
          final y = (inverseT * inverseT * startPos.dy +
                  2 * inverseT * t * controlPoint.dy +
                  t * t * center.dy)
              .toDouble();

          canvas.drawCircle(
            Offset(x, y),
            3.2,
            Paint()
              ..color = Colors.white
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
          canvas.drawCircle(
            Offset(x, y),
            1.8,
            Paint()..color = wan.color,
          );
        }
      }

      canvas.drawCircle(startPos, 15, Paint()..color = const Color(0xFF080D19));
      canvas.drawCircle(
        startPos,
        15,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(startPos, 3, Paint()..color = lineColor);
      _drawText(
        canvas,
        startPos.translate(0, 21),
        wan.name,
        lineColor,
        10,
        isBold: true,
      );
    }

    final hasOnlineLine = wans.any((wan) => wan.isOnline);
    final coreColor = hasOnlineLine
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF5252);
    final corePulse =
        hasOnlineLine ? math.sin(animationValue * 2 * math.pi) * 5 : 0.0;

    canvas.drawCircle(
      center,
      coreRadius + corePulse,
      Paint()
        ..color = coreColor.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()..color = const Color(0xFF080D19),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..color = coreColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center,
      coreRadius - 7,
      Paint()
        ..color = coreColor.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawText(canvas, center.translate(0, -12), 'مركز', coreColor, 15,
        isBold: true);
    _drawText(canvas, center.translate(0, 8), 'الدمج', Colors.white, 13,
        isBold: true);
  }

  void _drawText(
    Canvas canvas,
    Offset position,
    String text,
    Color color,
    double fontSize, {
    bool isBold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 7)],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, position.translate(-painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _ReactorPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.wans != wans;
}
