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
    final resource = provider.systemResource;

    String metric(String key, {String suffix = ''}) {
      final value = resource[key];
      if (value == null || value.toString().trim().isEmpty) return '--';
      return '$value$suffix';
    }

    String countOrPlaceholder(int count) =>
        provider.isConnected ? count.toString() : '--';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAIF.NET',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPurple)),
                      Text('لوحة تحكم الميكروتك',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.cardDark,
                    child: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: AppTheme.primaryBlue),
                      tooltip: 'تحديث بيانات الراوتر',
                      onPressed: () async {
                        await provider.fetchSystemResource();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildStatCard(
                        'المعالج', metric('cpu-load', suffix: '%'),
                        AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                        'الفولت', metric('voltage'), AppTheme.successGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                        'الحرارة',
                        metric('temperature', suffix: '°'),
                        AppTheme.warningOrange),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                        'وقت التشغيل', metric('uptime'),
                        AppTheme.primaryPurple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                        'سرعة النت', '--', AppTheme.primaryBlue),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
              Row(
                children: [
                  Expanded(
                    child: _buildGridCard(
                        Icons.router,
                        'البرودباند',
                        countOrPlaceholder(provider.pppoeUsers.length)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGridCard(
                        Icons.wifi,
                        'هوتسبوت',
                        countOrPlaceholder(provider.hotspotUsers.length)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildGridCard(Icons.people, 'يوزر منجر', '--'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGridCard(
                        Icons.miscellaneous_services, 'الإضافات', '--'),
                  ),
                ],
              ),
              if (!provider.isConnected && provider.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    provider.errorMessage,
                    style: const TextStyle(color: AppTheme.dangerRed),
                  ),
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
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold),
              textDirection: TextDirection.ltr),
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
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
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
