import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared ambient background for the authenticated application shell.
/// Kept behind the routed page so screen content remains readable and interactive.
class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.bgDeep),
        Positioned(
          top: -150,
          right: -110,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(.19),
                    AppColors.primary.withOpacity(.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 260,
          left: -180,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(.09),
                    AppColors.secondary.withOpacity(.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -210,
          right: -70,
          child: IgnorePointer(
            child: Container(
              width: 390,
              height: 390,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryStrong.withOpacity(.13),
                    AppColors.primaryStrong.withOpacity(.035),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
