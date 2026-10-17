import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderColor,
    this.glowColor,
    this.radius,
    this.elevated = false,
    this.blur = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? glowColor;
  final double? radius;
  final bool elevated;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.lg;
    final border = borderColor ?? AppColors.border;
    final glow = glowColor;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: AppColors.primary.withOpacity(0.06),
        highlightColor: AppColors.primary.withOpacity(0.03),
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: glow != null
            ? AppShadows.glow(glow)
            : (elevated ? AppShadows.soft : null),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.glass,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: border, width: 1),
              color: AppColors.bgCard.withOpacity(0.55),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}