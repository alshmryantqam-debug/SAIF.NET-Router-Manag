import 'dart:ui';

import 'package:flutter/material.dart';

class CyberHotspotCard extends StatelessWidget {
  final String name;
  final String profile;
  final String limitUptime;
  final bool isDisabled;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const CyberHotspotCard({
    super.key,
    required this.name,
    required this.profile,
    required this.limitUptime,
    required this.isDisabled,
    required this.onToggle,
    required this.onDelete,
  });

  static const _magenta = Color(0xFFE040FB);
  static const _danger = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final accentColor = isDisabled ? _danger : _magenta;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF070B14).withOpacity(0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.06),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 96,
                  decoration: BoxDecoration(
                    color: accentColor,
                    boxShadow: [BoxShadow(color: accentColor, blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                    gradient: RadialGradient(
                      colors: [accentColor.withOpacity(0.3), Colors.transparent],
                    ),
                  ),
                  child: Icon(Icons.wifi_tethering_rounded,
                      color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _dataTag('PROF: $profile'),
                            if (limitUptime.isNotEmpty)
                              _dataTag('LIMIT: $limitUptime'),
                            _dataTag(isDisabled ? 'STATUS: OFFLINE' : 'STATUS: ENABLED',
                                color: accentColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch.adaptive(
                      value: !isDisabled,
                      activeColor: accentColor,
                      activeTrackColor: accentColor.withOpacity(0.3),
                      inactiveThumbColor: Colors.white54,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      onChanged: (_) => onToggle(),
                    ),
                    IconButton(
                      tooltip: 'حذف المستخدم',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white54, size: 21),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataTag(String value, {Color color = Colors.white70}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
