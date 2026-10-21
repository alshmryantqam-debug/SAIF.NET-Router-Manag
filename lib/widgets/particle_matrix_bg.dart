import 'dart:math';

import 'package:flutter/material.dart';

/// A lightweight animated particle field for the holographic dashboard.
class Particle {
  Particle(this.x, this.y, this.vx, this.vy);

  double x;
  double y;
  double vx;
  double vy;
}

class ParticleMatrixBg extends StatefulWidget {
  const ParticleMatrixBg({
    super.key,
    required this.child,
    this.particleCount = 30,
  });

  final Widget child;
  final int particleCount;

  @override
  State<ParticleMatrixBg> createState() => _ParticleMatrixBgState();
}

class _ParticleMatrixBgState extends State<ParticleMatrixBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Particle> _particles = <Particle>[];
  final Random _random = Random();
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _syncParticles(Size size) {
    if (_lastSize == size && _particles.length == widget.particleCount) {
      return;
    }

    final previousSize = _lastSize;
    if (previousSize != null &&
        previousSize.width > 0 &&
        previousSize.height > 0) {
      for (final particle in _particles) {
        particle.x = (particle.x / previousSize.width) * size.width;
        particle.y = (particle.y / previousSize.height) * size.height;
      }
    }

    while (_particles.length < widget.particleCount) {
      _particles.add(
        Particle(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
          (_random.nextDouble() - 0.5) * 0.7,
          (_random.nextDouble() - 0.5) * 0.7,
        ),
      );
    }
    if (_particles.length > widget.particleCount) {
      _particles.removeRange(widget.particleCount, _particles.length);
    }

    _lastSize = size;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
        );
        _syncParticles(size);

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF070914)),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    _advanceParticles(size);
                    return CustomPaint(
                      painter: _ParticlePainter(particles: _particles),
                      size: size,
                    );
                  },
                ),
              ),
            ),
            SafeArea(child: widget.child),
          ],
        );
      },
    );
  }

  void _advanceParticles(Size size) {
    for (final particle in _particles) {
      particle.x += particle.vx;
      particle.y += particle.vy;

      if (particle.x < 0) {
        particle.x = 0;
        particle.vx = particle.vx.abs();
      } else if (particle.x > size.width) {
        particle.x = size.width;
        particle.vx = -particle.vx.abs();
      }

      if (particle.y < 0) {
        particle.y = 0;
        particle.vy = particle.vy.abs();
      } else if (particle.y > size.height) {
        particle.y = size.height;
        particle.vy = -particle.vy.abs();
      }
    }
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles});

  final List<Particle> particles;

  static const Color _cyan = Color(0xFF8C78FF);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _cyan.withOpacity(0.24)
      ..strokeWidth = 1;
    final dotPaint = Paint()
      ..color = const Color(0xFF8DEBFF).withOpacity(0.78)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < particles.length; i++) {
      final a = particles[i];
      canvas.drawCircle(Offset(a.x, a.y), 2, dotPaint);

      for (var j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final distanceSquared = dx * dx + dy * dy;

        if (distanceSquared < 10000) {
          final distance = sqrt(distanceSquared);
          linePaint.color = _cyan.withOpacity((1 - distance / 100) * 0.5);
          canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
