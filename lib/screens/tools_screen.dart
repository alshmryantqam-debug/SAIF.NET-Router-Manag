import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/nova_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';
import 'interfaces_screen.dart';
import 'cyber_shield_screen.dart';
import 'hotspot_operations_screen.dart';
import 'wan_ttl_screen.dart';
import 'terminal_screen.dart';
import 'load_balancing_wizard_screen.dart';
import 'queues_screen.dart';
import 'settings_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = <_Tool>[
      _Tool('إعدادات WAN وTTL', 'حالة الواجهات والمسارات وقاعدة TTL', Icons.alt_route_rounded, const WanTtlScreen()),
      _Tool('إدارة الهوتسبوت المتقدمة', 'الجلسات والبروفايلات وتصدير البطاقات', Icons.wifi_tethering_rounded, const HotspotOperationsScreen()),
      _Tool('درع الحماية السيبراني', 'قواعد الجدار الناري والعناوين المحظورة', Icons.shield_outlined, const CyberShieldScreen()),
      _Tool('معالج PCC', 'موازنة خطوط الإنترنت', Icons.account_tree_outlined, const LoadBalancingWizardScreen()),
      _Tool('الطوابير', 'إدارة حدود السرعة', Icons.speed_outlined, const QueuesScreen()),
      _Tool('الواجهات والمنافذ', 'حالة خطوط الإنترنت ومراقبة الاستخدام', Icons.cable_outlined, const InterfacesScreen()),
      _Tool('الإعدادات', 'اتصال الراوتر وأمان التطبيق', Icons.settings_outlined, const SettingsScreen()),
      _Tool('محسّن الألعاب', 'توجيه الألعاب وتقليل التأخير', Icons.sports_esports_outlined),
      _Tool('النسخ الاحتياطي', 'حفظ واستعادة الإعدادات', Icons.backup_outlined),
      _Tool('غرفة العمليات', 'سجل الراوتر وأوامر آمنة', Icons.receipt_long_outlined, const TerminalScreen()),
      _Tool('الفوترة', 'الاشتراكات والإيرادات', Icons.payments_outlined),
    ];
    return Scaffold(appBar: AppBar(title: const Text('الأدوات')), body: RefreshIndicator(
      onRefresh: () async { await HapticFeedback.lightImpact(); },
      child: GridView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .9),
        itemBuilder: (context, i) {
          final item = items[i];
          return Opacity(opacity: item.screen == null ? .6 : 1, child: GlassCard(padding: EdgeInsets.zero, child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: item.screen == null ? null : () async {
              await HapticFeedback.lightImpact();
              if (!context.mounted) return;
              Navigator.push(context, PageRouteBuilder<void>(pageBuilder: (_, __, ___) => item.screen!, transitionDuration: const Duration(milliseconds: 260), transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));
            },
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: NovaColors.primary.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(item.icon, color: NovaColors.primary)), const Spacer(), if (item.screen == null) const StatusPill('قريباً', NovaColors.warn)]),
              const Spacer(), Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(item.subtitle, style: const TextStyle(fontSize: 12, color: NovaColors.muted)),
            ])),
          )));
        },
      ),
    ));
  }
}
class _Tool {
  final String title, subtitle;
  final IconData icon;
  final Widget? screen;
  const _Tool(this.title, this.subtitle, this.icon, [this.screen]);
}
