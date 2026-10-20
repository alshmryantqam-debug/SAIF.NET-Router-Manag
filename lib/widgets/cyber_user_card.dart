import 'dart:ui';

import 'package:flutter/material.dart';

/// Tactical glass card for a PPPoE subscriber.
class CyberUserCard extends StatelessWidget {
  final String name;
  final String profile;
  final bool isDisabled;
  final VoidCallback onToggle;
  final String? detail;

  const CyberUserCard({
    Key? key,
    required this.name,
    required this.profile,
    required this.isDisabled,
    required this.onToggle,
    this.detail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = isDisabled
        ? const Color(0xFFFF4081)
        : const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                // Neon state edge.
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Subscriber network node.
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Icon(Icons.hub_outlined, color: statusColor, size: 20),
                ),
                const SizedBox(width: 16),

                // HUD subscriber data.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.speed,
                              color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'PROFILE: $profile',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (detail != null && detail!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail!,
                          style: const TextStyle(
                            color: Color(0xFF8DA9BD),
                            fontSize: 9,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Cyber enable/disable control.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12, left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      isDisabled ? 'OFFLINE' : 'ONLINE',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
