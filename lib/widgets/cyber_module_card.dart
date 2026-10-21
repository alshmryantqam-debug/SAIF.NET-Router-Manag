import 'dart:ui';
import 'package:flutter/material.dart';

class CyberModuleCard extends StatelessWidget {
  final String title;
  final String? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CyberModuleCard({
    Key? key,
    required this.title,
    this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.025),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.34), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.07),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.10),
                  border: Border.all(color: color.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.16), blurRadius: 16),
                  ],
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 11),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(height: 5),
                Text(
                  count!,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
