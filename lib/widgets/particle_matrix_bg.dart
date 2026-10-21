import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticleMatrixBg extends StatefulWidget {
  final Widget child;
  const ParticleMatrixBg({Key? key, required this.child}) : super(key: key);

  @override
  State<ParticleMatrixBg> createState() => _ParticleMatrixBgState();
}

class _ParticleMatrixBgState extends State<ParticleMatrixBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF090D1A), Color(0xFF100B20), Color(0xFF070A13)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _MatrixPainter(_controller.value),
            child: const SizedBox.expand(),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _MatrixPainter extends CustomPainter {
  final double phase;
  _MatrixPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00D9FF).withOpacity(0.045)
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final random = math.Random(27);
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 48; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY + phase * size.height * (i.isEven ? 1 : -1)) % size.height;
      particlePaint.color = (i % 3 == 0
              ? const Color(0xFFE040FB)
              : const Color(0xFF00E5FF))
          .withOpacity(0.10 + (i % 4) * 0.035);
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.5 : 0.8, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
