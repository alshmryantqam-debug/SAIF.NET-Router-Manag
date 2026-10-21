import 'dart:ui';

import 'package:flutter/material.dart';

class CyberFusionSlider extends StatelessWidget {
  final String interfaceName;
  final double weight;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  const CyberFusionSlider({
    Key? key,
    required this.interfaceName,
    required this.weight,
    required this.onChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.05),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.settings_input_component,
                            color: Color(0xFF00E5FF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              interfaceName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFFF5252),
                      ),
                      onPressed: onRemove,
                      tooltip: 'إزالة الخط من الاندماج',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'WEIGHT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${weight.toInt()}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF00E5FF),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                  ),
                  child: Slider(
                    value: weight.clamp(1.0, 10.0).toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: onChanged,
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
