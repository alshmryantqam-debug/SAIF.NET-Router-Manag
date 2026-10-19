import 'package:flutter/material.dart';
import '../theme.dart';
import 'terminal_screen.dart';
import 'interfaces_screen.dart';
import 'queues_screen.dart';
import 'load_balancing_wizard_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('المزيد والإعدادات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuTile(context, 'الطرفية (Terminal)', Icons.terminal, const TerminalScreen()),
          _buildMenuTile(context, 'المنافذ (Interfaces)', Icons.settings_input_component, const InterfacesScreen()),
          _buildMenuTile(context, 'الطوابير (Queues)', Icons.speed, const QueuesScreen()),
          _buildMenuTile(context, 'دمج الخطوط (PCC)', Icons.alt_route, const LoadBalancingWizardScreen()),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.dangerRed),
            title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.dangerRed)),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, IconData icon, Widget screen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }
}