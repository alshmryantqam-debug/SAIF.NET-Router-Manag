import 'dart:math' as math;

import 'package:flutter/material.dart';

class CyberOracleBrain extends StatefulWidget {
  final bool isScanning;
  final bool hasCritical;
  final bool hasResolved;

  const CyberOracleBrain({
    super.key,
    required this.isScanning,
    required this.hasCritical,
    this.hasResolved = false,
  });

  @override
  State<CyberOracleBrain> createState() => _CyberOracleBrainState();
}

class _CyberOracleBrainState extends State<CyberOracleBrain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _nodes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final random = math.Random(31);
    _nodes = List.generate(
      19,
      (_) => Offset(random.nextDouble() * 220 - 110, random.nextDouble() * 180 - 90),
    );
    if (widget.isScanning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CyberOracleBrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 245,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _CyberOraclePainter(
              phase: _controller.value,
              isScanning: widget.isScanning,
              hasCritical: widget.hasCritical,
              hasResolved: widget.hasResolved,
              nodes: _nodes,
            ),
          ),
        ),
      );
}

class _CyberOraclePainter extends CustomPainter {
  final double phase;
  final bool isScanning;
  final bool hasCritical;
  final bool hasResolved;
  final List<Offset> nodes;

  const _CyberOraclePainter({
    required this.phase,
    required this.isScanning,
    required this.hasCritical,
    required this.hasResolved,
    required this.nodes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreColor = hasCritical
        ? const Color(0xFFFF4058)
        : hasResolved
            ? const Color(0xFF43F5A5)
            : const Color(0xFF00E5FF);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isScanning) canvas.rotate(phase * math.pi / 8);

    final linkPaint = Paint()
      ..color = coreColor.withOpacity(isScanning ? 0.48 : 0.19)
      ..strokeWidth = 1.0;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if ((nodes[i] - nodes[j]).distance < 83) {
          canvas.drawLine(nodes[i], nodes[j], linkPaint);
        }
      }
    }

    for (var i = 0; i < nodes.length; i++) {
      final pulse = isScanning ? math.sin(phase * math.pi * 4 + i) * 2 : 0.0;
      final nodeColor = hasCritical && i % 5 == 0
          ? const Color(0xFFFF4058)
          : hasResolved && i % 4 == 0
              ? const Color(0xFF43F5A5)
              : coreColor;
      canvas.drawCircle(
        nodes[i],
        4 + pulse,
        Paint()
          ..color = nodeColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(nodes[i], 1.8, Paint()..color = Colors.white);
    }

    final halo = Paint()
      ..color = coreColor.withOpacity(0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset.zero, 32 + (isScanning ? phase * 8 : 0), halo);
    canvas.drawCircle(
      Offset.zero,
      17,
      Paint()
        ..color = coreColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(Offset.zero, 5, Paint()..color = coreColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CyberOraclePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.isScanning != isScanning ||
      oldDelegate.hasCritical != hasCritical ||
      oldDelegate.hasResolved != hasResolved;
}
