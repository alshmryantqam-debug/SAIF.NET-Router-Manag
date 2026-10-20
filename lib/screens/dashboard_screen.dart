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
import 'interfaces_screen.dart';
import 'pppoe_screen.dart';
import 'hotspot_screen.dart';
import 'queues_screen.dart';
import 'tools_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onOpenSection;
  const DashboardScreen({super.key, this.onOpenSection});
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
  void _openSection(int index, Widget fallback) {
    final callback = widget.onOpenSection;
    if (callback != null) {
      callback(index);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => fallback));
    }
  }
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
    final connected = s.onlineCount + h.activeCount;
    final expiring = s.all.where((u) => !u.expired && u.daysLeft != null && u.daysLeft! >= 0 && u.daysLeft! <= 3).length;
    final expired = s.all.where((u) => u.expired).length;
    return Scaffold(appBar: AppBar(title: const Text('نوڨا · مركز التحكم')), body: RefreshIndicator(
      onRefresh: _refresh, color: NovaColors.primary,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF596A91), Color(0xFF303A59), Color(0xFF252A40)]),
            borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _NovaCircle(icon: Icons.notifications_none_rounded, label: c.isConnected ? '✓' : '!', onTap: _refresh),
              const Spacer(),
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(28)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _NovaSegment(label: 'نوڨا', active: true),
                  _NovaSegment(label: c.isConnected ? 'متصل' : 'غير متصل', active: false, color: c.isConnected ? const Color(0xFF79D8B0) : const Color(0xFFFF858D)),
                ])),
              const Spacer(), _NovaCircle(icon: Icons.router_rounded, label: '', onTap: () => _showNovaInfo(context, 'معلومات الراوتر', 'الاسم: ${c.routerIdentity.isEmpty ? 'غير معروف' : c.routerIdentity}\nRouterOS: ${d.version.isEmpty ? '—' : d.version}')),
            ]),
            const SizedBox(height: 25),
            Text(c.routerIdentity.isEmpty ? 'مركز تحكم نوڨا' : c.routerIdentity, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 6),
            Text(c.isConnected ? 'حالة الشبكة · الاتصال يعمل بشكل طبيعي' : 'حالة الشبكة · تحقق من اتصال الراوتر', textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.visibility_off_outlined, color: Colors.white, size: 27)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${cpu.toStringAsFixed(0)}% CPU', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('RAM ${(ram * 100).toStringAsFixed(0)}% مستخدمة', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(.8))),
                Text('RouterOS ${d.version.isEmpty ? '—' : d.version}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.72))),
              ]),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _NovaAction(icon: Icons.refresh_rounded, label: 'تحديث البيانات', color: const Color(0xFF7CD7B1), onTap: _refresh)),
              const SizedBox(width: 12),
              Expanded(child: _NovaAction(icon: Icons.settings_ethernet_rounded, label: 'واجهات الشبكة', color: const Color(0xFFFF9099), onTap: () async => _openSection(1, const InterfacesScreen()))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _NovaQuick(icon: Icons.people_alt_rounded, label: 'المشتركون', onTap: () => _openSection(2, const PppoeScreen()))),
          Expanded(child: _NovaQuick(icon: Icons.wifi_tethering_rounded, label: 'الهوتسبوت', onTap: () => _openSection(3, const HotspotScreen()))),
          Expanded(child: _NovaQuick(icon: Icons.speed_rounded, label: 'السرعات', onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QueuesScreen())))),
          Expanded(child: _NovaQuick(icon: Icons.cable_rounded, label: 'الواجهات', onTap: () => _openSection(1, const InterfacesScreen()))),
          Expanded(child: _NovaQuick(icon: Icons.star_rounded, label: 'الأدوات', onTap: () => _openSection(4, const ToolsScreen()))),
        ]),
        const SectionTitle('ملخص الشبكة'),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5, children: [
          StatTile(icon: Icons.people_alt_outlined, label: 'متصلون الآن', value: '$connected', color: NovaColors.success),
          StatTile(icon: Icons.cable_outlined, label: 'واجهات الشبكة', value: '${t.interfaces.length}', color: NovaColors.primary),
        ]),
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
          StatTile(icon: Icons.people_alt_outlined, label: 'متصلون الآن', value: '$connected', color: NovaColors.success, hint: 'PPPoE + حسابات هوتسبوت مفعّلة'),
          StatTile(icon: Icons.event_available_outlined, label: 'تنتهي خلال 3 أيام', value: '$expiring', color: NovaColors.warn),
          StatTile(icon: Icons.event_busy_outlined, label: 'اشتراكات منتهية', value: '$expired', color: NovaColors.danger),
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
            ]))).toList())),
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
class _NovaCircle extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _NovaCircle({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(40), child: Stack(clipBehavior: Clip.none, children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.18), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.15))), child: Icon(icon, color: Colors.white, size: 25)),
    if (label.isNotEmpty) Positioned(top: -2, right: -2, child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFFFF626F), shape: BoxShape.circle), child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
  ]));
}
class _NovaSegment extends StatelessWidget {
  final String label; final bool active; final Color? color;
  const _NovaSegment({required this.label, required this.active, this.color});
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(2), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: active ? Colors.white.withOpacity(.20) : Colors.transparent, borderRadius: BorderRadius.circular(24)), child: Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w700, fontSize: 12)));
}
class _NovaAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final Future<void> Function() onTap;
  const _NovaAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, color: color), label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), side: BorderSide(color: Colors.white.withOpacity(.22)), shape: const StadiumBorder()));
}
class _NovaQuick extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _NovaQuick({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), child: Column(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFF34394F), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.12))), child: Icon(icon, color: Colors.white, size: 24)),
    const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
  ])));
}
void _showNovaInfo(BuildContext context, String title, String message) => showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF222638), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 14), Text(message, style: const TextStyle(color: Colors.white70, height: 1.7))]))));
