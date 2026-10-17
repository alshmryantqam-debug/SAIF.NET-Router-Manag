import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';
import '../widgets/live_chart.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _timer;
  final _cpu = <double>[];
  final _ram = <double>[];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.invalidate(systemResourceProvider);
      ref.invalidate(hotspotActiveProvider);
      ref.invalidate(pppoeActiveProvider);
      ref.invalidate(interfacesProvider);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    ref.invalidate(systemResourceProvider);
    ref.invalidate(identityProvider);
    ref.invalidate(hotspotUsersProvider);
    ref.invalidate(hotspotActiveProvider);
    ref.invalidate(pppoeUsersProvider);
    ref.invalidate(pppoeActiveProvider);
    ref.invalidate(interfacesProvider);
    ref.invalidate(dhcpLeasesProvider);
    ref.invalidate(firewallRulesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  @override
  Widget build(BuildContext context) {
    final resource = ref.watch(systemResourceProvider);
    final identity = ref.watch(identityProvider).valueOrNull ?? 'راوتر الشبكة';
    final conn = ref.watch(connectionProvider);
    final hotActive = ref.watch(hotspotActiveProvider).valueOrNull?.length ?? 0;
    final pppActive = ref.watch(pppoeActiveProvider).valueOrNull?.length ?? 0;
    final hotTotal = ref.watch(hotspotUsersProvider).valueOrNull?.length ?? 0;
    final pppTotal = ref.watch(pppoeUsersProvider).valueOrNull?.length ?? 0;
    final interfaces = ref.watch(interfacesProvider).valueOrNull ?? <InterfaceInfo>[];
    final leases = ref.watch(dhcpLeasesProvider).valueOrNull ?? [];
    final firewall = ref.watch(firewallRulesProvider).valueOrNull ?? [];
    final up = interfaces.where((e) => e.running && !e.disabled).length;

    return RefreshIndicator(
      onRefresh: _refresh, color: AppColors.primary, backgroundColor: AppColors.bgCard,
      child: resource.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _error(e),
        data: (r) {
          if (_cpu.length >= 36) _cpu.removeAt(0);
          _cpu.add(r.cpuLoad.toDouble());
          if (_ram.length >= 36) _ram.removeAt(0);
          _ram.add(r.memUsedPercent);
          final alerts = (r.cpuLoad >= 80 ? 1 : 0) + (r.memUsedPercent >= 85 ? 1 : 0) + (interfaces.isNotEmpty && up == 0 ? 1 : 0);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 112),
            children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(15), boxShadow: AppShadows.glow(AppColors.primary, opacity: .22)), child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TikPlus ULTRA', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(identity, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.success.withOpacity(.1), border: Border.all(color: AppColors.success.withOpacity(.3)), borderRadius: BorderRadius.circular(30)), child: const Row(children: [Icon(Icons.circle, size: 7, color: AppColors.success), SizedBox(width: 6), Text('متصل', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800))])),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF402263), Color(0xFF24183F), Color(0xFF151126)]),
                  borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.primary.withOpacity(.4)),
                  boxShadow: AppShadows.glow(AppColors.primary, opacity: .12),
                ),
                child: Stack(children: [
                  Positioned(left: -18, top: -28, child: Icon(Icons.radar_rounded, size: 132, color: Colors.white.withOpacity(.04))),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD8B7FF), size: 18), const SizedBox(width: 7), Text('مركز قيادة الشبكة', style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.bolt_rounded, color: AppColors.accent)]),
                    const SizedBox(height: 16),
                    const Text('شبكتك تحت السيطرة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 7),
                    Text('راقب الراوتر والمشتركين والموارد من شاشة واحدة.', style: TextStyle(color: Colors.white.withOpacity(.74), fontSize: 12, height: 1.5)),
                    const SizedBox(height: 17),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      _chip(Icons.router_rounded, r.version.isEmpty ? 'RouterOS' : r.version),
                      _chip(Icons.speed_rounded, conn.result == null ? 'زمن الاستجابة —' : '${conn.result!.latencyMs} ms'),
                      _chip(alerts == 0 ? Icons.verified_rounded : Icons.warning_amber_rounded, alerts == 0 ? 'الحالة مستقرة' : '${alerts} تنبيه'),
                    ]),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              _heading('مؤشرات الشبكة', 'بيانات الراوتر'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45,
                children: [
                  _metric('Hotspot نشط', '$hotActive', 'من أصل $hotTotal حساب', Icons.wifi_rounded, AppColors.success, () => context.go('/hotspot')),
                  _metric('جلسات PPPoE', '$pppActive', 'من أصل $pppTotal حساب', Icons.cable_rounded, AppColors.secondary, () => context.go('/pppoe')),
                  _metric('واجهات تعمل', '$up/${interfaces.length}', 'حالة المنافذ', Icons.account_tree_rounded, up == 0 ? AppColors.warning : AppColors.primary, () => context.push('/interfaces')),
                  _metric('DHCP Clients', '${leases.length}', 'عناوين مكتشفة', Icons.devices_rounded, AppColors.accent, () => context.push('/interfaces')),
                ],
              ),
              const SizedBox(height: 20),
              _heading('صحة الراوتر', 'مراقبة الموارد'),
              const SizedBox(height: 10),
              _resource('المعالج', r.cpuLoad.toDouble(), '${r.cpuLoad}%', '${r.cpuCount} نواة', Icons.memory_rounded, r.cpuLoad >= 80 ? AppColors.danger : AppColors.primary),
              const SizedBox(height: 10),
              _resource('الذاكرة', r.memUsedPercent, '${r.memUsedPercent.toStringAsFixed(0)}%', '${_bytes(r.totalMemory - r.freeMemory)} مستخدم من ${_bytes(r.totalMemory)}', Icons.storage_rounded, r.memUsedPercent >= 85 ? AppColors.danger : AppColors.secondary),
              const SizedBox(height: 14),
              LiveChart(values: _cpu, color: AppColors.primary, title: 'حمل المعالج', unit: '%', maxY: 100),
              const SizedBox(height: 12),
              LiveChart(values: _ram, color: AppColors.secondary, title: 'استخدام الذاكرة', unit: '%', maxY: 100),
              const SizedBox(height: 20),
              _heading('مركز التنبيهات', 'فحص سريع'),
              const SizedBox(height: 10),
              _alertPanel(r.cpuLoad, r.memUsedPercent, interfaces, up, firewall.length),
              const SizedBox(height: 20),
              _heading('أدوات صاحب الشبكة', 'اختصارات عملية'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: .94,
                children: [
                  _action('توليد الكروت', Icons.confirmation_number_rounded, AppColors.accent, () => context.go('/voucher')),
                  _action('الراوترات', Icons.router_rounded, AppColors.primary, () => context.push('/routers')),
                  _action('الجدار الناري', Icons.shield_rounded, AppColors.danger, () => context.push('/firewall')),
                  _action('Terminal', Icons.terminal_rounded, AppColors.warning, () => context.push('/terminal')),
                  _action('المشتركون', Icons.people_alt_rounded, AppColors.success, () => context.go('/hotspot')),
                  _action('تحديث الآن', Icons.sync_rounded, AppColors.secondary, _refresh),
                ],
              ),
              const SizedBox(height: 18),
              _deviceInfo(r),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withOpacity(.08))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: const Color(0xFFD8B7FF)), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))]),
  );

  Widget _heading(String title, String hint) => Row(children: [
    Container(width: 4, height: 19, decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 9),
    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
    const Spacer(),
    Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
  ]);

  Widget _metric(String title, String value, String hint, IconData icon, Color color, VoidCallback onTap) => Material(
    color: AppColors.bgCard, borderRadius: BorderRadius.circular(19),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(19), child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), border: Border.all(color: color.withOpacity(.22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Container(width: 33, height: 33, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), const Spacer(), Icon(Icons.arrow_outward_rounded, color: AppColors.textMuted.withOpacity(.7), size: 14)]),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w900, height: 1)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
        ]),
      ]),
    )),
  );

  Widget _resource(String title, double value, String display, String hint, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))])),
        Text(display, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: value.clamp(0.0, 100.0).toDouble() / 100, minHeight: 7, backgroundColor: Colors.white.withOpacity(.06), valueColor: AlwaysStoppedAnimation<Color>(color))),
    ]),
  );

  Widget _alertPanel(int cpu, double memory, List<InterfaceInfo> interfaces, int up, int firewallCount) {
    final alerts = <({IconData icon, Color color, String title, String detail})>[];
    if (cpu >= 80) alerts.add((icon: Icons.memory_rounded, color: AppColors.danger, title: 'حمل المعالج مرتفع', detail: 'المعالج عند $cpu%؛ راجع العمليات والقواعد الثقيلة.'));
    if (memory >= 85) alerts.add((icon: Icons.storage_rounded, color: AppColors.warning, title: 'الذاكرة مرتفعة', detail: 'استخدام الذاكرة ${memory.toStringAsFixed(0)}%.'));
    if (interfaces.isNotEmpty && up == 0) alerts.add((icon: Icons.portable_wifi_off_rounded, color: AppColors.danger, title: 'لا توجد واجهات عاملة', detail: 'افحص حالة المنافذ والاتصالات.'));
    if (alerts.isEmpty) alerts.add((icon: Icons.verified_rounded, color: AppColors.success, title: 'المؤشرات الأساسية مستقرة', detail: 'لا توجد إشارة حرجة في قراءات المعالج والذاكرة والواجهات.'));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        ...alerts.map((a) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(a.icon, color: a.color, size: 20), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title, style: TextStyle(color: a.color, fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(a.detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4))])),
        ]))),
        const Divider(color: AppColors.border, height: 20),
        Row(children: [const Icon(Icons.shield_outlined, color: AppColors.textMuted, size: 16), const SizedBox(width: 7), Expanded(child: Text('قواعد الجدار الناري: $firewallCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5))), TextButton(onPressed: () => context.push('/firewall'), child: const Text('فحص'))]),
      ]),
    );
  }

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) => Material(
    color: AppColors.bgCard, borderRadius: BorderRadius.circular(17),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(.22), color.withOpacity(.05)]), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 8),
        Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    )),
  );

  Widget _deviceInfo(SystemResource r) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.memory_rounded, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('تفاصيل الجهاز', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 10),
      _info('اللوحة', r.boardName), _info('إصدار RouterOS', r.version), _info('المعمارية', r.architecture), _info('مدة التشغيل', r.uptime),
      _info('التخزين المتاح', r.totalHdd > 0 ? '${_bytes(r.freeHdd)} / ${_bytes(r.totalHdd)}' : 'غير متاح'),
    ]),
  );

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))), Flexible(child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)))]),
  );

  Widget _error(Object error) => ListView(padding: const EdgeInsets.all(24), children: [
    const SizedBox(height: 70),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Column(children: [
      const Icon(Icons.cloud_off_rounded, size: 58, color: AppColors.danger), const SizedBox(height: 14),
      const Text('تعذر قراءة بيانات الراوتر', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), Text(error.toString().replaceAll('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 16), FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
    ])),
  ]);

  static String _bytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble(); var i = 0;
    while (size >= 1024 && i < units.length - 1) { size /= 1024; i++; }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}
