import 'dart:math' as math;

import 'package:flutter/material.dart';

/// رسم موجات RX/TX بتأثير نيون وشبكة تكتيكية، دون مكتبات رسوم خارجية.
class CyberTrafficGraph extends StatefulWidget {
  const CyberTrafficGraph({
    super.key,
    required this.rxData,
    required this.txData,
    required this.maxValue,
    this.height = 220,
  });

  final List<double> rxData;
  final List<double> txData;
  final double maxValue;
  final double height;

  @override
  State<CyberTrafficGraph> createState() => _CyberTrafficGraphState();
}

class _CyberTrafficGraphState extends State<CyberTrafficGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeMax = widget.maxValue.isFinite && widget.maxValue > 0
        ? widget.maxValue
        : 1.0;
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xB8050914),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2600E5FF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => CustomPaint(
            painter: _GraphPainter(
              rxData: widget.rxData,
              txData: widget.txData,
              maxValue: safeMax,
              phase: _pulse.value,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.rxData,
    required this.txData,
    required this.maxValue,
    required this.phase,
  });

  final List<double> rxData;
  final List<double> txData;
  final double maxValue;
  final double phase;

  static const Color _rx = Color(0xFF00E5FF);
  static const Color _tx = Color(0xFFE040FB);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final grid = Paint()
      ..color = _rx.withOpacity(0.075)
      ..strokeWidth = 0.7;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final axis = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axis);
    }

    _drawSeries(canvas, size, rxData, _rx);
    _drawSeries(canvas, size, txData, _tx);

    // خط مسح متحرك يوضح أن المخطط حي، دون إخفاء منحنيات البيانات.
    final scanX = size.width * phase;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          _rx.withOpacity(0.05),
          _rx.withOpacity(0.48),
          _rx.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0, 0.35, 0.5, 0.65, 1],
      ).createShader(Rect.fromLTWH(scanX - 18, 0, 36, size.height))
      ..strokeWidth = 1.4;
    canvas.drawRect(
      Rect.fromLTWH(math.max(0, scanX - 18), 0, 36, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rx.withOpacity(0), _rx.withOpacity(0.10), _rx.withOpacity(0)],
        ).createShader(Rect.fromLTWH(scanX - 18, 0, 36, size.height)),
    );
    canvas.drawLine(
      Offset(scanX, 0),
      Offset(scanX, size.height),
      scanPaint..shader = null..color = _rx.withOpacity(0.72),
    );
    canvas.drawLine(
      Offset(scanX, 0),
      Offset(scanX, size.height),
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 0.7,
    );
  }

  void _drawSeries(Canvas canvas, Size size, List<double> data, Color color) {
    if (data.isEmpty) return;
    final values = data.length > 60 ? data.sublist(data.length - 60) : data;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final raw = values[i];
      final value = raw.isFinite ? raw.clamp(0.0, maxValue).toDouble() : 0.0;
      final y = size.height - (value / maxValue) * (size.height - 8) - 4;
      points.add(Offset(i * stepX, y.clamp(0.0, size.height).toDouble()));
    }
    if (points.length == 1) points.insert(0, Offset(0, points.first.dy));

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.22), color.withOpacity(0.005)],
        ).createShader(Offset.zero & size),
    );

    final glow = Paint()
      ..color = color.withOpacity(0.34 + (0.22 * (0.5 + 0.5 * math.sin(phase * math.pi * 2))))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, glow);

    final core = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, core);

    final dot = points.last;
    canvas.drawCircle(dot, 4.5, Paint()..color = color.withOpacity(0.18));
    canvas.drawCircle(dot, 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.rxData != rxData ||
      oldDelegate.txData != txData ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.phase != phase;
}
