import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/live_dashboard_provider.dart';
import '../widgets/live_gauge_chart.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import 'hotspot_screen.dart';
import 'cyber_defense_screen.dart';
import 'quantum_domination_screen.dart';
import 'btest_command_screen.dart';
import 'torch_analyzer_screen.dart';
import 'surgical_operations_screen.dart';
import 'autonomous_ai_screen.dart';
import 'load_balancing_wizard_screen.dart';
import 'pppoe_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LiveDashboardProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<LiveDashboardProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connProvider = context.watch<ConnectionProvider>();
    final dashProvider = context.watch<LiveDashboardProvider>();

    final double totalRam = double.tryParse(dashProvider.totalMemory) ?? 0;
    final double freeRam = double.tryParse(dashProvider.freeMemory) ?? 0;
    final double usedRam = (totalRam - freeRam).clamp(0, totalRam).toDouble();
    final double ramUsagePercent = totalRam > 0
        ? (usedRam / totalRam).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final double cpuPercent = ((dashProvider.cpuLoad) / 100)
        .clamp(0.0, 1.0)
        .toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إدارة شبكة SAIF.NET'),
            Text(
              connProvider.routerIdentity.isEmpty
                  ? 'الراوتر'
                  : connProvider.routerIdentity,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.cardColor,
        onRefresh: dashProvider.fetchResources,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                useGradient: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'موديل المخدم',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'RouterOS ${dashProvider.version}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dashProvider.boardName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        _buildMiniStat(Icons.timer_outlined, 'مدة التشغيل',
                            dashProvider.uptime),
                        _buildMiniStat(Icons.memory, 'إجمالي الرام',
                            '${dashProvider.totalMemory} MB'),
                      ],
                    ),
                  ],
                ),
              ),
              if (dashProvider.hasError)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67).withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF4D67).withOpacity(.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF4D67)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dashProvider.errorMessage,
                          style: const TextStyle(color: Color(0xFFFF8091), fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إعادة المحاولة',
                        onPressed: dashProvider.fetchResources,
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF4D67)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'مراقبة الموارد (مباشر)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LiveGaugeChart(
                      title: 'المعالج (CPU)',
                      percentage: cpuPercent,
                      activeColor: const Color(0xFF00E5FF),
                      isOffline: dashProvider.hasError,
                      size: 94,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiveGaugeChart(
                      title: 'الذاكرة (RAM)',
                      percentage: ramUsagePercent,
                      activeColor: const Color(0xFFE5C158),
                      isOffline: dashProvider.hasError,
                      size: 94,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.memory, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الذاكرة المستخدمة: ${usedRam.toStringAsFixed(1)} MB',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    Text('من ${dashProvider.totalMemory} MB',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PppoeScreen()),
                    );
                  },
                  icon: const Icon(Icons.people_alt,
                      color: AppTheme.primaryColor),
                  label: const Text('إدارة مشتركي PPPoE',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(
                        color: AppTheme.warningColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HotspotScreen()),
                    );
                  },
                  icon: const Icon(Icons.wifi_tethering,
                      color: AppTheme.warningColor),
                  label: const Text('إدارة شبكة الهوتسبوت',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFF27C9FF), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CyberDefenseScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_moon_rounded, color: Color(0xFF27C9FF)),
                  label: const Text(
                    'درع الحماية السيبراني',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27C9FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TorchAnalyzerScreen()),
                  ),
                  icon: const Icon(Icons.radar_rounded, color: Color(0xFFFF5252)),
                  label: const Text('مصيدة الحزم السيبرانية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5252))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFF00D9FF), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BtestCommandScreen()),
                    );
                  },
                  icon: const Icon(Icons.speed_rounded, color: Color(0xFF00D9FF)),
                  label: const Text(
                    'مفاعل قياس سعة الاتصال',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00D9FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QuantumDominationScreen()),
                    );
                  },
                  icon: const Icon(Icons.hub_rounded, color: Color(0xFFE040FB)),
                  label: const Text(
                    'مصفوفة تدفق البيانات والتحكم',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE040FB)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(
                      color: Color(0xFF9C27B0),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoadBalancingWizardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.call_split,
                    color: Color(0xFF9C27B0),
                  ),
                  label: const Text(
                    'معالج دمج الخطوط (PCC)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AutonomousAiScreen()),
                  ),
                  icon: const Icon(Icons.psychology_alt_rounded, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'أوراكل | التشخيص الذاتي للشبكة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    side: const BorderSide(color: Color(0xFF4CAE7D), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SurgicalOperationsScreen()),
                  ),
                  icon: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF4CAE7D)),
                  label: const Text(
                    'غرفة العمليات الجراحية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAE7D)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              if (!connProvider.isConnected)
                const Text('حالة الاتصال: غير متصل',
                    style: TextStyle(color: AppTheme.dangerColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
          ],
        ),
      ],
    );
  }

  Color _getColorForUsage(double percentage) {
    if (percentage < 50) return AppTheme.successColor;
    if (percentage < 80) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }
}
