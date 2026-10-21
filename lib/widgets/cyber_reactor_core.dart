import 'dart:math';

import 'package:flutter/material.dart';

/// Animated visual core. Its state is driven by the caller's real apply state.
class CyberReactorCore extends StatefulWidget {
  const CyberReactorCore({super.key, this.isFusing = false});

  final bool isFusing;

  @override
  State<CyberReactorCore> createState() => _CyberReactorCoreState();
}

class _CyberReactorCoreState extends State<CyberReactorCore>
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
  Widget build(BuildContext context) {
    final coreColor = widget.isFusing
        ? const Color(0xFFE040FB)
        : const Color(0xFF00E5FF);

    return Semantics(
      label: widget.isFusing
          ? 'Quantum fusion reactor is applying PCC'
          : 'Quantum fusion reactor standby',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value * 2 * pi;
          final pulse = sin(phase);
          return SizedBox(
            width: 224,
            height: 224,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 188 + pulse * 10,
                  height: 188 + pulse * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: coreColor.withOpacity(
                          widget.isFusing ? 0.27 : 0.16,
                        ),
                        blurRadius: 42,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                Transform.rotate(
                  angle: phase * 0.45,
                  child: CustomPaint(
                    size: const Size(194, 194),
                    painter: _SegmentRingPainter(
                      color: coreColor,
                      segments: 4,
                      strokeWidth: 3.5,
                      sweepFactor: 0.64,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -phase * 0.82,
                  child: CustomPaint(
                    size: const Size(158, 158),
                    painter: _SegmentRingPainter(
                      color: coreColor.withOpacity(0.52),
                      segments: 8,
                      strokeWidth: 2.2,
                      sweepFactor: 0.48,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: phase * 1.25,
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: _SegmentRingPainter(
                      color: Colors.white.withOpacity(0.62),
                      segments: 3,
                      strokeWidth: 1.4,
                      sweepFactor: 0.34,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(cos(phase) * 88, sin(phase) * 88),
                  child: _OrbitNode(color: coreColor, size: 10),
                ),
                Transform.translate(
                  offset: Offset(
                    cos(-phase * 0.7 + pi) * 67,
                    sin(-phase * 0.7 + pi) * 67,
                  ),
                  child: const _OrbitNode(
                    color: Color(0xFF8A5CFF),
                    size: 7,
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF20233C), Color(0xFF050811)],
                    ),
                    border: Border.all(color: coreColor, width: 2.4),
                    boxShadow: [
                      BoxShadow(
                        color: coreColor.withOpacity(0.68),
                        blurRadius: widget.isFusing ? 30 : 22,
                        spreadRadius: widget.isFusing ? 3 : 1,
                      ),
                      BoxShadow(
                        color: const Color(0xFF8A5CFF).withOpacity(0.32),
                        blurRadius: 34,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.isFusing
                          ? Icons.electric_bolt_rounded
                          : Icons.hub_rounded,
                      color: coreColor,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrbitNode extends StatelessWidget {
  const _OrbitNode({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 15, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _SegmentRingPainter extends CustomPainter {
  const _SegmentRingPainter({
    required this.color,
    required this.segments,
    required this.strokeWidth,
    required this.sweepFactor,
  });

  final Color color;
  final int segments;
  final double strokeWidth;
  final double sweepFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - strokeWidth;
    final sweepAngle = (2 * pi / segments) * sweepFactor;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var index = 0; index < segments; index++) {
      final startAngle = -pi / 2 + (2 * pi / segments) * index;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.segments != segments ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sweepFactor != sweepFactor;
}
