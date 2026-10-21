import 'dart:math';

import 'package:flutter/material.dart';

class CyberTargetCrosshair extends StatefulWidget {
  final bool isPinging;
  final bool isTimeout;

  const CyberTargetCrosshair({
    super.key,
    this.isPinging = false,
    this.isTimeout = false,
  });

  @override
  State<CyberTargetCrosshair> createState() => _CyberTargetCrosshairState();
}

class _CyberTargetCrosshairState extends State<CyberTargetCrosshair>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.isPinging ? 1 : 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant CyberTargetCrosshair oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDuration = widget.isPinging
        ? const Duration(milliseconds: 800)
        : const Duration(seconds: 4);
    if (_controller.duration != nextDuration) {
      _controller.duration = nextDuration;
      _controller
        ..stop()
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
    final targetColor = widget.isTimeout
        ? const Color(0xFFFF5252)
        : widget.isPinging
            ? const Color(0xFFE040FB)
            : const Color(0xFF00E5FF);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: targetColor.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: _controller.value * 2 * pi,
                child: CustomPaint(
                  painter: _CrosshairPainter(color: targetColor),
                  size: const Size(200, 200),
                ),
              ),
              Transform.rotate(
                angle: -_controller.value * 2 * pi,
                child: CustomPaint(
                  painter: _InnerTargetPainter(color: targetColor),
                  size: const Size(100, 100),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: targetColor,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: targetColor, blurRadius: 10),
                  ],
                ),
              ),
              if (widget.isPinging && !widget.isTimeout)
                IgnorePointer(
                  child: Container(
                    width: 200 * _controller.value,
                    height: 200 * _controller.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: targetColor.withOpacity(1 - _controller.value),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;

  const _CrosshairPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (pi / 2) * i + 0.2,
        (pi / 2) - 0.4,
        false,
        paint,
      );
    }

    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 3;
    canvas
      ..drawLine(Offset(center.dx, 0), Offset(center.dx, 15), tickPaint)
      ..drawLine(
        Offset(center.dx, size.height),
        Offset(center.dx, size.height - 15),
        tickPaint,
      )
      ..drawLine(Offset(0, center.dy), Offset(15, center.dy), tickPaint)
      ..drawLine(
        Offset(size.width, center.dy),
        Offset(size.width - 15, center.dy),
        tickPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _InnerTargetPainter extends CustomPainter {
  final Color color;

  const _InnerTargetPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final circlePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, size.width / 2, circlePaint);

    final bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const length = 15.0;

    canvas
      ..drawLine(const Offset(0, 0), const Offset(length, 0), bracketPaint)
      ..drawLine(const Offset(0, 0), const Offset(0, length), bracketPaint)
      ..drawLine(
        Offset(size.width, 0),
        Offset(size.width - length, 0),
        bracketPaint,
      )
      ..drawLine(
        Offset(size.width, 0),
        Offset(size.width, length),
        bracketPaint,
      )
      ..drawLine(
        Offset(0, size.height),
        Offset(length, size.height),
        bracketPaint,
      )
      ..drawLine(
        Offset(0, size.height),
        Offset(0, size.height - length),
        bracketPaint,
      )
      ..drawLine(
        Offset(size.width, size.height),
        Offset(size.width - length, size.height),
        bracketPaint,
      )
      ..drawLine(
        Offset(size.width, size.height),
        Offset(size.width, size.height - length),
        bracketPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _InnerTargetPainter oldDelegate) =>
      oldDelegate.color != color;
}
