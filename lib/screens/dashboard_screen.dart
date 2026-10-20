import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hotspot_provider.dart';
import '../providers/subscribers_provider.dart';
import '../providers/traffic_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/live_traffic_chart.dart';
import '../widgets/nova_widgets.dart';

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
      context.read<DashboardProvider>().startPolling();
      context.read<SubscribersProvider>().load();
      context.read<HotspotProvider>().fetchUsers();
    });
  }
  @override
  void dispose() { context.read<DashboardProvider>().stopPolling(); super.dispose(); }
  Future<void> _refresh() async {
    await Future.wait([
      context.read<DashboardProvider>().fetchResources(),
      context.read<SubscribersProvider>().load(),
      context.read<HotspotProvider>().fetchUsers(),
      context.read<ConnectionProvider>().fetchInterfaces(),
    ]);
  }
  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    final d = context.watch<DashboardProvider>();
    final t = context.watch<TrafficProvider>();
    final s = context.watch<SubscribersProvider>();
    final h = context.watch<HotspotProvider>();
    final cpu = ((double.tryParse(d.cpuLoad) ?? 0).clamp(0, 100)).toDouble();
    final total = double.tryParse(d.totalMemory) ?? 0;
    final free = double.tryParse(d.freeMemory) ?? 0;
    final ram = total > 0 ? ((total - free) / total).clamp(0, 1).toDouble() : 0.0;
    final connected = s.onlineCount + h.users.where((u) => !u.disabled).length;
    final expiring = s.all.where((u) => !u.expired && u.daysLeft != null && u.daysLeft! >= 0 && u.daysLeft! <= 3).length;
    final expired = s.all.where((u) => u.expired).length;
    return Scaffold(appBar: AppBar(title: const Text('SAIF.NET · لوحة الشبكة')), body: RefreshIndicator(
      onRefresh: _refresh, color: NovaColors.primary,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        GlassCard(useGradient: true, useBlur: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(gradient: NovaColors.gradient, borderRadius: BorderRadius.all(Radius.circular(16))), child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.routerIdentity.isEmpty ? 'راوتر MikroTik' : c.routerIdentity, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(d.boardName, style: const TextStyle(color: NovaColors.muted)),
            ])),
            StatusPill(c.isConnected ? 'متصل' : 'مقطوع', c.isConnected ? NovaColors.success : NovaColors.danger),
          ]),
          const Divider(height: 24),
          Wrap(spacing: 16, runSpacing: 8, children: [
            Text('RouterOS: ${d.version.isEmpty ? '—' : d.version}', style: const TextStyle(color: NovaColors.muted)),
            Text('مدة التشغيل: ${d.uptime}', style: const TextStyle(color: NovaColors.muted)),
          ]),
        ])),
        const SectionTitle('الخطوط · WAN'),
        SizedBox(height: 128, child: t.interfaces.isEmpty
          ? const EmptyState(icon: Icons.cable_outlined, title: 'لا توجد واجهات', message: 'اسحب للأسفل لتحديث البيانات.')
          : ListView.separated(scrollDirection: Axis.horizontal, itemCount: t.interfaces.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) {
              final iface = t.interfaces[i]; final data = t.history[iface.name] ?? const [];
              final last = data.isEmpty ? null : data.last;
              return SizedBox(width: 185, child: GlassCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(iface.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('↓ ${last == null ? '—' : _speed(last.rx)}', style: const TextStyle(fontSize: 12)),
                Text('↑ ${last == null ? '—' : _speed(last.tx)}', style: const TextStyle(fontSize: 12)),
                const Spacer(), StatusPill(iface.running ? 'يعمل' : 'متوقف', iface.running ? NovaColors.success : NovaColors.danger),
              ])));
            })),
        const SectionTitle('ملخص المشتركين'),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.25, children: [
          StatTile(icon: Icons.people_alt_outlined, label: 'متصلون الآن', value: '§connected', color: NovaColors.success, hint: 'PPPoE + حسابات هوتسبوت مفعّلة'),
          StatTile(icon: Icons.event_available_outlined, label: 'تنتهي خلال 3 أيام', value: '§expiring', color: NovaColors.warn),
          StatTile(icon: Icons.event_busy_outlined, label: 'اشتراكات منتهية', value: '§expired', color: NovaColors.danger),
          StatTile(icon: Icons.payments_outlined, label: 'الإيراد المتوقع', value: '${s.expectedRevenue}', color: NovaColors.violet, hint: 'حسب أسعار PPPoE المسجلة'),
        ]),
        const SectionTitle('حركة الخطوط الحالية'),
        if (t.watched.isEmpty) const GlassCard(child: EmptyState(icon: Icons.show_chart, title: 'لا توجد خطوط مراقبة', message: 'ستظهر الرسوم بعد اكتشاف واجهات الراوتر.'))
        else ...t.watched.map((name) => LiveTrafficChart(name: name, data: t.history[name] ?? const [])),
        const SectionTitle('آخر الأحداث'),
        GlassCard(child: t.events.isEmpty
          ? const EmptyState(icon: Icons.history, title: 'لا توجد أحداث حديثة', message: 'ستظهر هنا تغيّرات حالة الخطوط.')
          : Column(children: t.events.take(12).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
              Icon(e.bad ? Icons.error_outline : Icons.check_circle_outline, color: e.bad ? NovaColors.danger : NovaColors.success, size: 19),
              const SizedBox(width: 8), Expanded(child: Text(e.text, style: TextStyle(color: e.bad ? NovaColors.danger : NovaColors.success, fontSize: 13))),
              Text(TimeOfDay.fromDateTime(e.t).format(context), style: const TextStyle(fontSize: 11, color: NovaColors.muted)),
            ])).toList())),
        const SectionTitle('موارد الراوتر'),
        GlassCard(child: Row(children: [
          Expanded(child: _Gauge('CPU', cpu / 100, '${cpu.toStringAsFixed(0)}%')),
          const SizedBox(width: 20),
          Expanded(child: _Gauge('RAM', ram, '${(ram * 100).toStringAsFixed(0)}%')),
        ])),
        if (s.loading || h.isLoading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2)),
      ]),
    ));
  }
  String _speed(double b) => b >= 1000000 ? '${(b / 1000000).toStringAsFixed(1)} Mbps' : b >= 1000 ? '${(b / 1000).toStringAsFixed(0)} Kbps' : '${b.toStringAsFixed(0)} bps';
}
class _Gauge extends StatelessWidget {
  final String label, text; final double value;
  const _Gauge(this.label, this.value, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 54, height: 54, child: Stack(fit: StackFit.expand, children: [
      CircularProgressIndicator(value: value, strokeWidth: 5, backgroundColor: NovaColors.border, color: value >= .8 ? NovaColors.danger : NovaColors.primary),
      Center(child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
    ])),
    const SizedBox(width: 10), Text(label, style: const TextStyle(color: NovaColors.muted, fontWeight: FontWeight.bold)),
  ]);
}
