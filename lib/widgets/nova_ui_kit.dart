import 'package:flutter/material.dart';

/// Nova's geometric UI primitives: clipped controls, technical frames and
/// a purpose-built pointer-driven weight rail (no Material Slider).
class NovaCyberButton extends StatelessWidget {
  const NovaCyberButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.onPressed,
    this.height = 65,
    this.compact = false,
  });

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = enabled ? color : const Color(0xFF657080);
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          decoration: BoxDecoration(
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.14),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            foregroundPainter: _CyberButtonFramePainter(color: accent),
            child: ClipPath(
              clipper: CyberButtonClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? [
                            accent.withOpacity(0.18),
                            const Color(0xE6090D18),
                            accent.withOpacity(0.06),
                          ]
                        : [
                            Colors.white.withOpacity(0.04),
                            const Color(0xE6090D18),
                          ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: accent, size: compact ? 20 : 27),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: compact ? 12 : 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: compact ? 0.7 : 1.4,
                            shadows: enabled
                                ? [Shadow(color: accent, blurRadius: 10)]
                                : const [],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CyberButtonClipper extends CustomClipper<Path> {
  const CyberButtonClipper({this.cut = 15});

  final double cut;

  @override
  Path getClip(Size size) {
    final c = cut.clamp(0.0, size.shortestSide / 3);
    return Path()
      ..moveTo(0, c)
      ..lineTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..close();
  }

  @override
  bool shouldReclip(covariant CyberButtonClipper oldClipper) =>
      oldClipper.cut != cut;
}

class _CyberButtonFramePainter extends CustomPainter {
  const _CyberButtonFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = CyberButtonClipper().getClip(size);
    final outline = Paint()
      ..color = color.withOpacity(0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    canvas.drawPath(path, outline);

    final marker = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(0, 15), const Offset(0, size.height - 15), marker);
    canvas.drawLine(
      Offset(size.width - 20, 1),
      Offset(size.width - 7, 1),
      marker..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberButtonFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class NovaTechPanel extends StatelessWidget {
  const NovaTechPanel({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xD91A2133),
            Color(0xE6090D18),
            Color(0xD9161028),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 22,
            spreadRadius: -3,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: TechFramePainter(color: accentColor),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class TechFramePainter extends CustomPainter {
  const TechFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRect(Offset.zero & size, faint);

    final bracket = Paint()
      ..color = color.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;
    const length = 23.0;
    const bevel = 8.0;

    final corners = <List<Offset>>[
      [Offset(0, bevel), Offset(0, length), Offset(0, 0), Offset(length, 0)],
      [
        Offset(size.width - length, 0),
        Offset(size.width, 0),
        Offset(size.width, length),
      ],
      [
        Offset(0, size.height - length),
        Offset(0, size.height),
        Offset(length, size.height),
      ],
      [
        Offset(size.width - length, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - length),
      ],
    ];
    for (final points in corners) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, bracket);
    }

    final topRail = Paint()
      ..color = color.withOpacity(0.22)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(length + 8, 0),
      Offset(size.width * 0.52, 0),
      topRail,
    );
  }

  @override
  bool shouldRepaint(covariant TechFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Discrete 1..10 control rendered as a glowing geometric rail.
class NovaWeightRail extends StatelessWidget {
  const NovaWeightRail({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.color = const Color(0xFFE040FB),
  });

  final double value;
  final ValueChanged<double> onChanged;
  final int min;
  final int max;
  final Color color;

  double _valueAt(double dx, double width) {
    final normalized = (dx / width).clamp(0.0, 1.0);
    final raw = min + normalized * (max - min);
    return raw.roundToDouble().clamp(min.toDouble(), max.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final bounded = value.clamp(min.toDouble(), max.toDouble()).toDouble();
    return Semantics(
      slider: true,
      value: bounded.toInt().toString(),
      increasedValue: (bounded + 1).clamp(min.toDouble(), max.toDouble()).toInt().toString(),
      decreasedValue: (bounded - 1).clamp(min.toDouble(), max.toDouble()).toInt().toString(),
      onIncrease: () => onChanged((bounded + 1).clamp(min.toDouble(), max.toDouble())),
      onDecrease: () => onChanged((bounded - 1).clamp(min.toDouble(), max.toDouble())),
      child: SizedBox(
        height: 42,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            void update(Offset localPosition) {
              onChanged(_valueAt(localPosition.dx, width));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => update(details.localPosition),
              onHorizontalDragUpdate: (details) => update(details.localPosition),
              child: CustomPaint(
                painter: _NovaWeightRailPainter(
                  value: bounded,
                  min: min,
                  max: max,
                  color: color,
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NovaWeightRailPainter extends CustomPainter {
  const _NovaWeightRailPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
  });

  final double value;
  final int min;
  final int max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 9.0;
    const right = 9.0;
    final width = size.width - left - right;
    final centerY = size.height / 2;
    final ratio = (value - min) / (max - min);
    final activeX = left + width * ratio;

    final inactive = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final active = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(left, centerY), Offset(size.width - right, centerY), inactive);
    canvas.drawLine(Offset(left, centerY), Offset(activeX, centerY), active);

    for (var step = min; step <= max; step++) {
      final x = left + width * ((step - min) / (max - min));
      final selected = step <= value.round();
      final tick = Paint()
        ..color = selected ? color : Colors.white.withOpacity(0.23)
        ..strokeWidth = selected ? 2 : 1;
      canvas.drawLine(
        Offset(x, centerY - (selected ? 7 : 4)),
        Offset(x, centerY + (selected ? 7 : 4)),
        tick,
      );
    }

    final glow = Paint()
      ..color = color.withOpacity(0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(Offset(activeX, centerY), 9, glow);
    final knob = Paint()
      ..color = const Color(0xFF080D19)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, centerY), 7, knob);
    canvas.drawCircle(
      Offset(activeX, centerY),
      7,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(activeX, centerY), 2.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _NovaWeightRailPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      oldDelegate.color != color;
}
