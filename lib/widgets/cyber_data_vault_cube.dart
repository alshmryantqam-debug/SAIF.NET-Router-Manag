import 'dart:math' as math;

import 'package:flutter/material.dart';

/// مكعب هولوغرافي متحرك لواجهة خزنة النسخ الاحتياطي.
class CyberDataVaultCube extends StatefulWidget {
  const CyberDataVaultCube({super.key, this.isProcessing = false});

  final bool isProcessing;

  @override
  State<CyberDataVaultCube> createState() => _CyberDataVaultCubeState();
}

class _CyberDataVaultCubeState extends State<CyberDataVaultCube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.isProcessing ? 1 : 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant CyberDataVaultCube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isProcessing != widget.isProcessing) {
      _controller
        ..duration = Duration(seconds: widget.isProcessing ? 1 : 8)
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
    final color = widget.isProcessing
        ? const Color(0xFFFF5252)
        : const Color(0xFF00E5FF);

    return SizedBox(
      height: 190,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(widget.isProcessing ? 0.40 : 0.22),
                      blurRadius: 52,
                      spreadRadius: 16,
                    ),
                  ],
                ),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0025)
                  ..rotateX(angle)
                  ..rotateY(angle * 0.82)
                  ..rotateZ(angle * 0.18),
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildFace(color, 104, 0),
                      _buildFace(color, 104, math.pi / 2),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateX(math.pi / 2),
                        child: _buildFace(color, 104, 0),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi / 4),
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: color.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF080D19).withOpacity(0.88),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.8)),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.35), blurRadius: 18),
                  ],
                ),
                child: Icon(
                  widget.isProcessing
                      ? Icons.enhanced_encryption_rounded
                      : Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFace(Color color, double size, double rotation) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(rotation),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.055),
          border: Border.all(color: color.withOpacity(0.92), width: 1.4),
        ),
        child: CustomPaint(painter: _GridFacePainter(color: color)),
      ),
    );
  }
}

class _GridFacePainter extends CustomPainter {
  const _GridFacePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.24)
      ..strokeWidth = 0.7;
    for (double x = 0; x <= size.width; x += 13) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 13) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const arm = 10.0;
    for (final point in <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = point.dx == 0 ? arm : -arm;
      final dy = point.dy == 0 ? arm : -arm;
      canvas.drawLine(point, point.translate(dx, 0), cornerPaint);
      canvas.drawLine(point, point.translate(0, dy), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridFacePainter oldDelegate) =>
      oldDelegate.color != color;
}
