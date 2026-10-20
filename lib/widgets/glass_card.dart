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
    this.blur = 25,
    this.useGradient = false,
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
  final bool useGradient;

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
              color: useGradient
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.04),
              gradient: useGradient
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primaryStrong.withOpacity(0.06),
                        Colors.white.withOpacity(0.025),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                if (glow != null)
                  BoxShadow(
                    color: glow.withOpacity(0.12),
                    blurRadius: 22,
                    spreadRadius: -2,
                  ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}