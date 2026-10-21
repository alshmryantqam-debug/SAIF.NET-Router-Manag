import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/torch_provider.dart';

class CyberTorchVisualizer extends StatefulWidget {
  final bool isSniffing;
  final List<TorchPacket> packets;
  const CyberTorchVisualizer({super.key, required this.isSniffing, required this.packets});

  @override
  State<CyberTorchVisualizer> createState() => _CyberTorchVisualizerState();
}

class _CyberTorchVisualizerState extends State<CyberTorchVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.isSniffing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant CyberTorchVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSniffing) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.3),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: widget.isSniffing ? const Color(0xFFFF5252).withOpacity(.6) : Colors.white10, width: 1.5),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _TorchPainter(_controller.value, widget.isSniffing, widget.packets),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _TorchPainter extends CustomPainter {
  final double phase;
  final bool active;
  final List<TorchPacket> packets;
  _TorchPainter(this.phase, this.active, this.packets);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFF00E5FF).withOpacity(.07)..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!active) return;
    final scanY = size.height * phase;
    final scanRect = Rect.fromLTRB(0, math.max(0, scanY - 42), size.width, scanY);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, const Color(0xFFFF5252).withOpacity(.55)],
      ).createShader(scanRect);
    canvas.drawRect(scanRect, scanPaint);
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY),
      Paint()..color = const Color(0xFFFF5252)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    for (var i = 0; i < packets.length; i++) {
      final packet = packets[i];
      final x = size.width * (i + 1) / (packets.length + 1);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
        Paint()..color = const Color(0xFF00E5FF).withOpacity(.12)..strokeWidth = 1);
      if ((scanY - size.height * .5).abs() < 24) {
        canvas.drawCircle(Offset(x, scanY), 4, Paint()..color = const Color(0xFF00E5FF).withOpacity(.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset(x, scanY), 2.3, Paint()..color = const Color(0xFF00E5FF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TorchPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.active != active || oldDelegate.packets != packets;
}
