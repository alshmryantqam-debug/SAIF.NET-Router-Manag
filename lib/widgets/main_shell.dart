import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/hotspot_screen.dart';
import '../screens/pppoe_screen.dart';
import '../screens/voucher_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/routers_list_screen.dart';
import '../screens/terminal_screen.dart';
import '../screens/network_diagnostics_screen.dart';
import '../screens/router_backup_screen.dart';
import '../theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    HotspotScreen(),
    PppoeScreen(),
    VoucherScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          title: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.secondary, AppTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAIF.NET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(height: 1),
                  Text('ROUTER MANAGER',
                      style: TextStyle(fontSize: 8, letterSpacing: 1.4, color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'أدوات الشبكة',
              icon: const Icon(Icons.apps_rounded),
              onSelected: (value) {
                final Widget page;
                switch (value) {
                  case 'routers':
                    page = const RoutersListScreen();
                    break;
                  case 'diagnostics':
                    page = const NetworkDiagnosticsScreen();
                    break;
                  case 'backups':
                    page = const RouterBackupScreen();
                    break;
                  default:
                    page = const TerminalScreen();
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'routers',
                  child: Row(children: [Icon(Icons.router_rounded), SizedBox(width: 10), Text('أجهزة الراوتر')]),
                ),
                PopupMenuItem(
                  value: 'diagnostics',
                  child: Row(children: [Icon(Icons.monitor_heart_rounded), SizedBox(width: 10), Text('مراقبة الشبكة')]),
                ),
                PopupMenuItem(
                  value: 'backups',
                  child: Row(children: [Icon(Icons.enhanced_encryption_rounded), SizedBox(width: 10), Text('النسخ المشفّرة')]),
                ),
                PopupMenuItem(
                  value: 'terminal',
                  child: Row(children: [Icon(Icons.terminal_rounded), SizedBox(width: 10), Text('الطرفية')]),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (value) => setState(() => _selectedIndex = value),
          backgroundColor: AppTheme.bgCard,
          indicatorColor: AppTheme.primary.withOpacity(0.16),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.wifi_outlined),
              selectedIcon: Icon(Icons.wifi_rounded),
              label: 'Hotspot',
            ),
            NavigationDestination(
              icon: Icon(Icons.cable_outlined),
              selectedIcon: Icon(Icons.cable_rounded),
              label: 'PPPoE',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number_rounded),
              label: 'الكروت',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
