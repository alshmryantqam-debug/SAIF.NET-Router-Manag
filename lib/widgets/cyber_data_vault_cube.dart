import 'dart:math' as math;

import 'package:flutter/material.dart';

/// مكعب هولوغرافي بحالات واضحة مع تحرير آمن لمتحكم الحركة.
class CyberDataVaultCube extends StatefulWidget {
  const CyberDataVaultCube({
    super.key,
    this.isProcessing = false,
    this.isSuccess = false,
    this.isFailed = false,
  });

  final bool isProcessing;
  final bool isSuccess;
  final bool isFailed;

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
      duration: Duration(milliseconds: widget.isProcessing ? 800 : 12000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant CyberDataVaultCube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isProcessing != widget.isProcessing) {
      _controller
        ..duration = Duration(
          milliseconds: widget.isProcessing ? 800 : 12000,
        )
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _color() {
    if (widget.isFailed) return const Color(0xFFFF5252);
    if (widget.isSuccess) return const Color(0xFF4CAE7D);
    if (widget.isProcessing) return const Color(0xFFE040FB);
    return const Color(0xFF00E5FF);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final statusIcon = widget.isProcessing
        ? Icons.sync_rounded
        : widget.isFailed
            ? Icons.error_outline_rounded
            : widget.isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.lock_outline_rounded;

    return SizedBox(
      height: 190,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 155,
                height: 155,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.22),
                      blurRadius: 52,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(angle)
                  ..rotateY(angle)
                  ..rotateZ(angle * 0.15),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildCubeFace(color, 110, 0),
                    _buildCubeFace(color, 110, math.pi / 2),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateX(math.pi / 2),
                      child: _buildCubeFace(color, 110, 0),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xE6090D18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.85)),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.24), blurRadius: 16),
                  ],
                ),
                child: Icon(statusIcon, color: Colors.white, size: 34),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCubeFace(Color color, double size, double rotation) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(rotation),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.85), width: 1.7),
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
    final grid = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _GridFacePainter oldDelegate) =>
      oldDelegate.color != color;
}
