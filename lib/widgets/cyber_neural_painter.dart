import 'dart:math';

import 'package:flutter/material.dart';

class NeuralNode {
  final double x;
  final double y;
  final bool isAnomalous;
  final double phaseOffset;

  const NeuralNode(this.x, this.y, this.isAnomalous, this.phaseOffset);
}

/// Animated, deterministic neural topology for the PPPoE command centre.
///
/// The nodes are intentionally illustrative until a Riverpod data source is
/// connected; red nodes are visual samples, not detected router incidents.
class CyberNeuralPainter extends StatefulWidget {
  final int nodeCount;

  const CyberNeuralPainter({super.key, this.nodeCount = 20});

  @override
  State<CyberNeuralPainter> createState() => _CyberNeuralPainterState();
}

class _CyberNeuralPainterState extends State<CyberNeuralPainter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<NeuralNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = _generateNodes(widget.nodeCount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  List<NeuralNode> _generateNodes(int count) {
    final random = Random(42);
    return List<NeuralNode>.generate(
      count.clamp(0, 120),
      (_) => NeuralNode(
        random.nextDouble(),
        random.nextDouble(),
        random.nextDouble() > 0.85,
        random.nextDouble() * 2 * pi,
      ),
      growable: false,
    );
  }

  @override
  void didUpdateWidget(covariant CyberNeuralPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeCount != widget.nodeCount) {
      _nodes = _generateNodes(widget.nodeCount);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _NeuralNetworkPainter(
              animationValue: _controller.value,
              nodes: _nodes,
            ),
            isComplex: true,
            willChange: true,
          ),
        ),
      ),
    );
  }
}

class _NeuralNetworkPainter extends CustomPainter {
  final double animationValue;
  final List<NeuralNode> nodes;

  const _NeuralNetworkPainter({
    required this.animationValue,
    required this.nodes,
  });

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFE040FB);
  static const Color _red = Color(0xFFFF5252);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final maxDist = size.width * 0.35;
    final positions = nodes
        .map((node) => Offset(node.x * size.width, node.y * size.height))
        .toList(growable: false);

    // Neural links and travelling data pulses.
    for (var i = 0; i < nodes.length; i++) {
      final p1 = positions[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final p2 = positions[j];
        final distance = (p1 - p2).distance;
        if (distance >= maxDist || maxDist <= 0) continue;

        final strength = 1 - distance / maxDist;
        final anomalous = nodes[i].isAnomalous || nodes[j].isAnomalous;
        final linkColor = anomalous ? _red : _cyan;

        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = linkColor.withOpacity(strength * 0.30)
            ..strokeWidth = 1.2,
        );

        if (strength > 0.2) {
          final pulse = (animationValue + i * 0.071 + j * 0.037) % 1.0;
          final pulsePoint = Offset(
            p1.dx + (p2.dx - p1.dx) * pulse,
            p1.dy + (p2.dy - p1.dy) * pulse,
          );
          canvas.drawCircle(
            pulsePoint,
            3.2,
            Paint()
              ..color = Colors.white.withOpacity(strength * 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
          canvas.drawCircle(
            pulsePoint,
            1.4,
            Paint()..color = linkColor.withOpacity(strength),
          );
        }
      }
    }

    // Subscriber nodes. Red nodes are demo anomalies until live data is wired.
    for (final node in nodes) {
      final position = Offset(node.x * size.width, node.y * size.height);
      final color = node.isAnomalous ? _red : _magenta;
      final pulse =
          (sin(animationValue * 2 * pi + node.phaseOffset) + 1) / 2;

      canvas.drawCircle(
        position,
        8 + pulse * 6,
        Paint()
          ..color = color.withOpacity(0.25 + pulse * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(position, 4, Paint()..color = color);
      canvas.drawCircle(position, 1.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralNetworkPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.nodes != nodes;
}
