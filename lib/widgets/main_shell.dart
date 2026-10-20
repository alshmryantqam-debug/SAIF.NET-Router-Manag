import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF191B28).withOpacity(0.95),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.dashboard_rounded, 'الرئيسية'),
                  _navItem(1, Icons.group_rounded, 'PPPoE'),
                  const SizedBox(width: 50),
                  _navItem(2, Icons.wifi_rounded, 'الهوتسبوت'),
                  _navItem(3, Icons.menu_rounded, 'المزيد'),
                ],
              ),
              // الزر العائم (يعمل الآن)
              Positioned(
                top: -25,
                child: GestureDetector(
                  onTap: () {
                    // استدعاء دالة التحديث من الـ Provider
                    context.read<ConnectionProvider>().refreshDashboard();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جاري تحديث البيانات...'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF718BDD), Color(0xFF5E7CCB)]),
                      border: Border.all(color: AppTheme.bgDark, width: 4),
                      boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.5), blurRadius: 15)],
                    ),
                    child: const Icon(Icons.sync, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _index == index;
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? AppTheme.primaryPurple : Colors.grey, size: 26),
          if (isActive) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }
}
