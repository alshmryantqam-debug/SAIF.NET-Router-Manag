import 'package:flutter/material.dart';

import '../theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.gradient,
    this.foreground = AppColors.bgDeep,
    this.height = 54,
    this.radius,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final Gradient? gradient;
  final Color foreground;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppGradients.primary;
    final r = radius ?? AppRadius.md;
    final disabled = onPressed == null || loading;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: SizedBox(
        height: height,
        width: fullWidth ? double.infinity : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: g,
            borderRadius: BorderRadius.circular(r),
            boxShadow: disabled
                ? null
                : AppShadows.glow(AppColors.primary, opacity: 0.28),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(r),
              onTap: disabled ? null : onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize:
                      fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(foreground),
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, color: foreground, size: 20),
                    if (loading || icon != null) const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}