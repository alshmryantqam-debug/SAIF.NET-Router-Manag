import 'package:flutter/material.dart';

import '../core/theme/nova_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/interfaces_screen.dart';
import '../screens/pppoe_screen.dart';
import '../screens/hotspot_screen.dart';
import '../screens/tools_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    DashboardScreen(onOpenSection: (index) {
      if (mounted) setState(() => _index = index.clamp(0, 4).toInt());
    }),
    const InterfacesScreen(),
    const PppoeScreen(),
    const HotspotScreen(),
    const ToolsScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.cable_outlined),
      selectedIcon: Icon(Icons.cable_rounded),
      label: 'الخطوط',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_alt_rounded),
      label: 'PPPoE',
    ),
    NavigationDestination(
      icon: Icon(Icons.wifi_tethering_outlined),
      selectedIcon: Icon(Icons.wifi_tethering_rounded),
      label: 'هوتسبوت',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_rounded),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'المزيد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF191B28),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.24),
                  blurRadius: 22,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                destinations: _destinations,
                backgroundColor: Colors.transparent,
                indicatorColor: NovaColors.primary.withOpacity(.22),
                height: 72,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
