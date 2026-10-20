import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A translucent glass surface. Keep the optional interaction and styling
/// parameters so existing screens can use GlassCard without API changes.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderColor,
    this.glowColor,
    this.radius = 24.0,
    this.elevated = false,
    this.blur = 25.0,
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
    final r = radius ?? 24.0;
    final glow = glowColor;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          splashColor: AppColors.primary.withOpacity(0.08),
          highlightColor: AppColors.primary.withOpacity(0.04),
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          boxShadow: [
            if (elevated) ...AppShadows.soft,
            if (glow != null) ...AppShadows.glow(glow),
          ],
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
                  color: borderColor ?? Colors.white.withOpacity(0.15),
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
      ),
    );
  }
}
