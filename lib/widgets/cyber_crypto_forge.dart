import 'dart:math' as math;

import 'package:flutter/material.dart';

/// محرك بصري متحرك لعملية صك البطاقات.
class CyberCryptoForge extends StatefulWidget {
  final bool isForging;

  const CyberCryptoForge({Key? key, this.isForging = false}) : super(key: key);

  @override
  State<CyberCryptoForge> createState() => _CyberCryptoForgeState();
}

class _CyberCryptoForgeState extends State<CyberCryptoForge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random.secure();
  static const String _characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  String _scrambled = 'NOVA-7X';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isForging) _controller.repeat();
    _controller.addListener(_updateScramble);
  }

  void _updateScramble() {
    if (!widget.isForging || !mounted) return;
    final value = List.generate(
      6,
      (_) => _characters[_random.nextInt(_characters.length)],
    ).join();
    if (value != _scrambled) setState(() => _scrambled = value);
  }

  @override
  void didUpdateWidget(covariant CyberCryptoForge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isForging && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isForging && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
      setState(() => _scrambled = 'NOVA-7X');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScramble);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isForging
        ? const Color(0xFFE040FB)
        : const Color(0xFF00E5FF);

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(widget.isForging ? 0.32 : 0.15),
                    blurRadius: widget.isForging ? 46 : 30,
                    spreadRadius: widget.isForging ? 12 : 5,
                  ),
                ],
              ),
            ),
            Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: CustomPaint(
                painter: _LockRingPainter(color: color),
                size: const Size(140, 140),
              ),
            ),
            Transform.rotate(
              angle: -(_controller.value * 2 * math.pi * 1.5),
              child: CustomPaint(
                painter: _LockRingPainter(
                  color: color.withOpacity(0.55),
                  isInner: true,
                ),
                size: const Size(100, 100),
              ),
            ),
            if (widget.isForging)
              Text(
                _scrambled,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 3,
                  shadows: [Shadow(color: Color(0xFFE040FB), blurRadius: 12)],
                ),
              )
            else
              Icon(Icons.enhanced_encryption_rounded, color: color, size: 40),
          ],
        ),
      ),
    );
  }
}

class _LockRingPainter extends CustomPainter {
  final Color color;
  final bool isInner;

  const _LockRingPainter({required this.color, this.isInner = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isInner ? 2 : 4;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segments = isInner ? 8 : 4;
    const gap = 0.2;
    final sweepAngle = (2 * math.pi / segments) - gap;

    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (2 * math.pi / segments) * i,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LockRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isInner != isInner;
}
