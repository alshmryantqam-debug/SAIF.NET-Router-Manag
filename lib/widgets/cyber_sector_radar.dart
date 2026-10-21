import 'dart:math';

import 'package:flutter/material.dart';

/// رادار قطاعي خفيف يرسم مجال المسح دون الاعتماد على مكتبات رسوم خارجية.
class CyberSectorRadar extends StatefulWidget {
  final bool isScanning;

  const CyberSectorRadar({super.key, this.isScanning = false});

  @override
  State<CyberSectorRadar> createState() => _CyberSectorRadarState();
}

class _CyberSectorRadarState extends State<CyberSectorRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _SectorPainter(
              animationValue: _controller.value,
              isScanning: widget.isScanning,
            ),
          ),
        ),
      );
}

class _SectorPainter extends CustomPainter {
  final double animationValue;
  final bool isScanning;

  const _SectorPainter({
    required this.animationValue,
    required this.isScanning,
  });

  static const Color _cyan = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.46;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..color = _cyan.withOpacity(isScanning ? 0.28 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final factor in [1.0, 0.72, 0.44, 0.16]) {
      canvas.drawCircle(center, radius * factor, ringPaint);
    }

    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ringPaint,
    );

    final sweepAngle = animationValue * 2 * pi;
    final sectorPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(bounds, sweepAngle - pi / 2, pi / 2, false)
      ..close();

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - pi / 2,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          _cyan.withOpacity(isScanning ? 0.24 : 0.10),
          _cyan.withOpacity(isScanning ? 0.62 : 0.28),
        ],
      ).createShader(bounds);

    canvas.drawPath(sectorPath, sweepPaint);

    final corePaint = Paint()..color = _cyan;
    canvas.drawCircle(center, 4.5, corePaint);
    canvas.drawCircle(
      center,
      isScanning ? 12 : 9,
      Paint()
        ..color = _cyan.withOpacity(isScanning ? 0.26 : 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SectorPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.isScanning != isScanning;
}
