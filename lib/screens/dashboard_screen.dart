import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../providers/connection_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final cpuLoad = provider.systemResource['cpu-load'] ?? '--';
    final activeUsers = provider.pppoeUsers.length;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Text('الرئيسية',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 15),
                        Text('التقارير',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      children: [
                        const Icon(Icons.notifications_none, color: Colors.white),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.visibility_off,
                                  color: Colors.white, size: 20),
                            ),
                            Column(
                              children: [
                                const Text('حمل المعالج (CPU)',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 15)),
                                const SizedBox(height: 5),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('$cpuLoad',
                                        style: const TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: -1)),
                                    const Text(' %',
                                        style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white70)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  provider.isConnected
                                      ? 'متصل بـ $activeUsers مشترك'
                                      : 'الراوتر غير متصل',
                                  style: TextStyle(
                                    color: provider.isConnected
                                        ? Colors.greenAccent
                                        : AppTheme.dangerRed,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardBtn(
                                'تحديث',
                                Icons.refresh,
                                AppTheme.successGreen,
                                () => provider.refreshDashboard(),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildCardBtn('الخطوط', Icons.alt_route,
                                  AppTheme.primaryPurple, () {}),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickAction(Icons.router, 'الراوترات'),
                  _quickAction(Icons.people, 'المشتركون'),
                  _quickAction(Icons.speed, 'الطوابير'),
                  _quickAction(Icons.receipt_long, 'الفواتير'),
                  _quickAction(Icons.star, 'المزيد'),
                ],
              ),
              const SizedBox(height: 30),
              const Text('آخر الجلسات النشطة',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 15),
              if (provider.pppoeUsers.isEmpty)
                const Center(
                  child: Text('لا يوجد مشتركون متصلون حالياً',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...provider.pppoeUsers.take(5).map(
                      (user) => _buildTransactionItem(
                        user.name,
                        user.profile,
                        user.disabled ? 'معطّل' : 'الحساب مفعّل',
                        user.disabled
                            ? AppTheme.dangerRed
                            : AppTheme.successGreen,
                      ),
                    ),
              if (provider.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  child: Text(provider.errorMessage,
                      style: const TextStyle(color: AppTheme.dangerRed)),
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTransactionItem(
      String name, String profile, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.person, color: statusColor, size: 20),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(profile,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(status,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
