import 'package:flutter/material.dart';

import '../models/router_config.dart';
import '../theme.dart';

class VersionSelector extends StatelessWidget {
  const VersionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final RouterVersion value;
  final ValueChanged<RouterVersion>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _option(
          version: RouterVersion.auto,
          label: 'تلقائي',
          subtitle: 'كشف ذكي',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.accent,
        ),
        const SizedBox(width: 8),
        _option(
          version: RouterVersion.v7,
          label: 'v7',
          subtitle: 'REST API',
          icon: Icons.rocket_launch_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _option(
          version: RouterVersion.v6,
          label: 'v6',
          subtitle: 'Binary API',
          icon: Icons.shield_rounded,
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _option({
    required RouterVersion version,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = value == version;
    final tappable = enabled && onChanged != null;

    return Expanded(
      child: InkWell(
        onTap: tappable ? () => onChanged!(version) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AppDurations.curve,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color.withOpacity(0.22),
                      color.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow:
                selected ? AppShadows.glow(color, opacity: 0.22) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? color : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected
                      ? color.withOpacity(0.75)
                      : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}