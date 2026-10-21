import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphism WAN editor. Changes are delegated to the Riverpod screen;
/// this component does not make router requests itself.
class CyberEnergyTube extends StatelessWidget {
  const CyberEnergyTube({
    super.key,
    required this.interfaceName,
    required this.weight,
    required this.onChanged,
    required this.onRemove,
    this.gatewayAddress = '',
    this.onGatewayChanged,
    this.availableInterfaces = const <String>[],
    this.onInterfaceChanged,
    this.canRemove = true,
  });

  final String interfaceName;
  final double weight;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;
  final String gatewayAddress;
  final ValueChanged<String>? onGatewayChanged;
  final List<String> availableInterfaces;
  final ValueChanged<String>? onInterfaceChanged;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final boundedWeight = weight.clamp(1.0, 10.0).toDouble();
    final energyColor = Color.lerp(
      const Color(0xFF00E5FF),
      const Color(0xFFE040FB),
      (boundedWeight / 10).clamp(0.0, 1.0).toDouble(),
    )!;

    final options = List<String>.of(availableInterfaces);
    if (interfaceName.isNotEmpty && !options.contains(interfaceName)) {
      options.insert(0, interfaceName);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xE61A2135),
                  Color(0xD90B1020),
                  Color(0xE6161027),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: energyColor.withOpacity(0.48),
                width: 1.35,
              ),
              boxShadow: [
                BoxShadow(
                  color: energyColor.withOpacity(0.11),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
                const BoxShadow(
                  color: Color(0x90000000),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        energyColor.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: energyColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: energyColor.withOpacity(0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: energyColor.withOpacity(0.12),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings_input_hdmi_rounded,
                        color: energyColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            interfaceName.isEmpty
                                ? 'WAN SOURCE'
                                : interfaceName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              fontSize: 15,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PCC ENERGY INPUT',
                            style: TextStyle(
                              color: energyColor.withOpacity(0.9),
                              fontFamily: 'monospace',
                              fontSize: 9,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: canRemove
                          ? 'إزالة مصدر WAN'
                          : 'يلزم وجود خطّي WAN على الأقل',
                      onPressed: canRemove ? onRemove : null,
                      icon: Icon(
                        Icons.power_settings_new_rounded,
                        color: canRemove
                            ? const Color(0xFFFF6B84)
                            : Colors.white24,
                      ),
                    ),
                  ],
                ),
                if (options.isNotEmpty && onInterfaceChanged != null) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: options.contains(interfaceName)
                        ? interfaceName
                        : null,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF12182A),
                    iconEnabledColor: energyColor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'واجهة WAN الفعلية',
                      labelStyle: TextStyle(color: energyColor),
                      prefixIcon: Icon(Icons.cable_rounded, color: energyColor),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(
                          color: energyColor.withOpacity(0.25),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(
                          color: energyColor.withOpacity(0.22),
                        ),
                      ),
                    ),
                    items: options
                        .map(
                          (name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onInterfaceChanged!.call(value);
                    },
                  ),
                ],
                if (onGatewayChanged != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey<String>('wan-gateway-' + interfaceName),
                    initialValue: gatewayAddress,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: onGatewayChanged,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'بوابة WAN • Gateway IPv4',
                      hintText: '192.168.1.1',
                      helperText: 'أدخل بوابة هذا الخط الفعلية من جدول التوجيه',
                      helperStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                      labelStyle: TextStyle(color: energyColor),
                      prefixIcon: Icon(Icons.route_rounded, color: energyColor),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(
                          color: energyColor.withOpacity(0.25),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(
                          color: energyColor.withOpacity(0.22),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'POWER RATIO  ' + boundedWeight.toInt().toString(),
                        style: TextStyle(
                          color: energyColor,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(10, (index) {
                        final isActive = index < boundedWeight.round();
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(left: 3),
                          width: 6,
                          height: 13,
                          decoration: BoxDecoration(
                            color: isActive
                                ? energyColor
                                : Colors.white.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: energyColor.withOpacity(0.75),
                                      blurRadius: 7,
                                    ),
                                  ]
                                : const [],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: energyColor,
                    inactiveTrackColor: Colors.white.withOpacity(0.11),
                    thumbColor: Colors.white,
                    overlayColor: energyColor.withOpacity(0.18),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                      elevation: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 19,
                    ),
                  ),
                  child: Slider(
                    value: boundedWeight,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: onChanged,
                  ),
                ),
                Text(
                  'الوزن نسبة توزيع اتصالات وليس قياساً مباشراً لسرعة الخط.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.46),
                    fontSize: 10,
                    height: 1.35,
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
