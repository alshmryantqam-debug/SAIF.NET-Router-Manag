import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/pppoe_screen.dart';
import '../screens/hotspot_screen.dart';
import '../screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PppoeScreen(),
    const HotspotScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      extendBody: true,
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.cardDark.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.dashboard_rounded, 'الرئيسية'),
            _navItem(1, Icons.group_rounded, 'PPPoE'),
            _navItem(2, Icons.wifi_rounded, 'الهوتسبوت'),
            _navItem(3, Icons.menu_rounded, 'المزيد'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _index == index;
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryPurple.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryPurple : AppTheme.textMuted,
              size: 26,
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
