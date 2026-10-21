import 'dart:math' as math;
import 'package:flutter/material.dart';

/// رسم متحرك لعدادات تدفق مستمدة من بيانات شجرة الطوابير الحقيقية.
class CyberDataStream extends StatefulWidget {
  final double gamingTraffic;
  final double socialTraffic;
  final double streamingTraffic;

  const CyberDataStream({
    super.key,
    required this.gamingTraffic,
    required this.socialTraffic,
    required this.streamingTraffic,
  });

  @override
  State<CyberDataStream> createState() => _CyberDataStreamState();
}

class _CyberDataStreamState extends State<CyberDataStream>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 270,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _CyberDataPainter(
              phase: _controller.value,
              gaming: widget.gamingTraffic.clamp(0.0, 1.0).toDouble(),
              social: widget.socialTraffic.clamp(0.0, 1.0).toDouble(),
              streaming: widget.streamingTraffic.clamp(0.0, 1.0).toDouble(),
            ),
          ),
        ),
      );
}

class _CyberDataPainter extends CustomPainter {
  final double phase;
  final double gaming;
  final double social;
  final double streaming;

  const _CyberDataPainter({
    required this.phase,
    required this.gaming,
    required this.social,
    required this.streaming,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 34);
    _drawStream(canvas, center, Offset(size.width * .17, 60), gaming,
        const Color(0xFF4CAE7D), 'الألعاب');
    _drawStream(canvas, center, Offset(size.width * .50, 36), social,
        const Color(0xFFE040FB), 'التواصل');
    _drawStream(canvas, center, Offset(size.width * .83, 60), streaming,
        const Color(0xFFFF6B6B), 'البث المرئي');

    final glow = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, 28, glow);
    canvas.drawCircle(center, 21, Paint()..color = const Color(0xFF100B1C));
    canvas.drawCircle(
      center,
      21,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, 'نواة الشبكة', center.translate(0, 30),
        const Color(0xFF00E5FF), 10, center: true);
  }

  void _drawStream(Canvas canvas, Offset start, Offset end, double load,
      Color color, String label) {
    final control = Offset((start.dx + end.dx) / 2, end.dy + 70);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final count = 1 + (load * 8).round();
    for (var i = 0; i < count; i++) {
      final t = (phase + i / count) % 1.0;
      final x = math.pow(1 - t, 2) * start.dx +
          2 * (1 - t) * t * control.dx +
          math.pow(t, 2) * end.dx;
      final y = math.pow(1 - t, 2) * start.dy +
          2 * (1 - t) * t * control.dy +
          math.pow(t, 2) * end.dy;
      final point = Offset(x.toDouble(), y.toDouble());
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = color.withOpacity(.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(point, 2, Paint()..color = color);
    }

    canvas.drawCircle(end, 23, Paint()..color = color.withOpacity(.12));
    canvas.drawCircle(
      end,
      16,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, label, end.translate(0, -43), Colors.white, 10,
        center: true);
    _drawText(canvas, '${(load * 100).round()}%', end.translate(0, -5),
        color, 12, center: true);
  }

  void _drawText(Canvas canvas, String value, Offset point, Color color,
      double size, {bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: color.withOpacity(.5), blurRadius: 7)],
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 150);
    painter.paint(
      canvas,
      Offset(point.dx - (center ? painter.width / 2 : 0),
          point.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CyberDataPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.gaming != gaming ||
      oldDelegate.social != social ||
      oldDelegate.streaming != streaming;
}
