import 'dart:ui';

import 'package:flutter/material.dart';

class CyberHotspotCard extends StatelessWidget {
  final String name;
  final String profile;
  final String bytesOut;
  final String uptime;
  final bool isDisabled;
  final VoidCallback onToggle;

  const CyberHotspotCard({
    super.key,
    required this.name,
    required this.profile,
    required this.bytesOut,
    required this.uptime,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDisabled
        ? const Color(0xFFFF5252)
        : const Color(0xFFE040FB);
    final mbOut = (double.tryParse(bytesOut) ?? 0) / 1048576;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 90,
                  decoration: BoxDecoration(
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(color: accentColor, blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withOpacity(0.5),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.wifi_tethering_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _dataTag('PROF: $profile'),
                            _dataTag('UP: $uptime'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bytesOut.trim().isEmpty
                              ? 'DATA USED: N/A'
                              : 'DATA USED: ${mbOut.toStringAsFixed(1)} MB',
                          style: TextStyle(
                            color: accentColor.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: isDisabled ? 'تفعيل المستخدم' : 'تعطيل المستخدم',
                    onPressed: onToggle,
                    icon: Icon(
                      isDisabled
                          ? Icons.toggle_off_rounded
                          : Icons.toggle_on_rounded,
                      color: accentColor,
                      size: 34,
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

  Widget _dataTag(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
