import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'pppoe_screen.dart';
import 'hotspot_screen.dart';
import 'tools_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    PppoeScreen(),
    HotspotScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'المشتركون',
            ),
            NavigationDestination(
              icon: Icon(Icons.wifi_tethering_outlined),
              selectedIcon: Icon(Icons.wifi_tethering),
              label: 'الهوتسبوت',
            ),
            NavigationDestination(
              icon: Icon(Icons.construction_outlined),
              selectedIcon: Icon(Icons.construction),
              label: 'الأدوات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      );
}
