import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('نوڨا', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                      Text('لوحة تحكم الميكروتك', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.cardDark,
                    child: IconButton(icon: const Icon(Icons.logout, color: AppTheme.dangerRed), onPressed: () {}),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Row 1: CPU, Voltage, Temp
              Row(
                children: [
                  Expanded(flex: 2, child: _buildStatCard('المعالج', '${provider.systemResource['cpu-load'] ?? 0}%', AppTheme.primaryBlue)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildStatCard('الفولت', 'غير متوفر', AppTheme.successGreen)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildStatCard('الحرارة', '47°', AppTheme.warningOrange)),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Uptime, Net Speed
              Row(
                children: [
                  Expanded(child: _buildStatCard('وقت التشغيل', '${provider.systemResource['uptime'] ?? '--'}', AppTheme.primaryPurple)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('سرعة النت', '18.7 م/ث', AppTheme.primaryBlue)),
                ],
              ),
              const SizedBox(height: 10),

              // Search / Action Buttons
              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconBtn(Icons.settings, 'ضبط السرعة'),
                    _buildIconBtn(Icons.speed, 'قياس السرعة'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Grid of Stats
              Row(
                children: [
                  Expanded(child: _buildGridCard(Icons.router, 'البرودباند', '195 من 274')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGridCard(Icons.wifi, 'هوتسبوت', '1964')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildGridCard(Icons.people, 'يوزر منجر', '30')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGridCard(Icons.miscellaneous_services, 'الإضافات', '')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
        ],
      ),
    );
  }

  Widget _buildGridCard(IconData icon, String title, String subtitle) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 40),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if(subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, String title) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryPurple, size: 30),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
