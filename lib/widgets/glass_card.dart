import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/nova_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width, height;
  final EdgeInsetsGeometry padding, margin;
  final BorderRadius? borderRadius;
  final bool useGradient, useBlur;
  final Color? color;
  const GlassCard({super.key, required this.child, this.width, this.height, this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero, this.borderRadius, this.useGradient = false, this.useBlur = false, this.color});
  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final content = Container(width: width, height: height, padding: padding, decoration: BoxDecoration(
      gradient: color == null ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: useGradient ? [NovaColors.surface2, NovaColors.surface] : [NovaColors.surface.withOpacity(.98), NovaColors.surface2.withOpacity(.8)]) : null,
      color: color, borderRadius: radius, border: Border.all(color: NovaColors.border, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 18, offset: const Offset(0, 7))],
    ), child: child);
    return Padding(padding: margin, child: useBlur
      ? ClipRRect(borderRadius: radius, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: content))
      : ClipRRect(borderRadius: radius, child: content));
  }
}
