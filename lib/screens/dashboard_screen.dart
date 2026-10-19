import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/predictive_history.dart';
import 'advanced_ai_screens.dart';
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
      ref.invalidate(routerServicesProvider);
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
    ref.invalidate(routerServicesProvider);
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
    final firewallState = ref.watch(firewallRulesProvider);
    final firewall = firewallState.valueOrNull ?? [];
    final routerServices = ref.watch(routerServicesProvider);
    final activeHotspot = ref.watch(hotspotActiveProvider).valueOrNull ?? <Map<String, String>>[];
    final up = interfaces.where((e) => e.running && !e.disabled).length;

    return RefreshIndicator(
      onRefresh: _refresh, color: AppColors.primary, backgroundColor: AppColors.bgCard,
      child: resource.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _error(e),
        data: (r) {
          unawaited(PredictiveHistory.recordIfDue(r.cpuLoad.toDouble(), r.memUsedPercent));
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
                  const Text('SAIF.NET', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
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
                    const Text('مركز عمليات شبكتك', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 7),
                    Text('إدارة احترافية للمنافذ والمشتركين والأمان وحركة المرور من مركز واحد.', style: TextStyle(color: Colors.white.withOpacity(.74), fontSize: 12, height: 1.5)),
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
              const SizedBox(height: 12),
              const PredictiveDashboardCard(),
              const SizedBox(height: 20),
              _heading('مركز التنبيهات', 'فحص سريع'),
              const SizedBox(height: 10),
              _alertPanel(r.cpuLoad, r.memUsedPercent, interfaces, up, firewall.length),
              const SizedBox(height: 20),
              _heading('مؤشر أمان الراوتر', 'تدقيق للقراءة فقط'),
              const SizedBox(height: 10),
              _securityScore(routerServices, firewallState),
              const SizedBox(height: 20),
              _heading('تدفق حركة المرور', 'عدادات الواجهات'),
              const SizedBox(height: 10),
              _trafficFlow(interfaces),
              const SizedBox(height: 20),
              _heading('الأكثر استهلاكاً', 'أعلى 5 جلسات نشطة'),
              const SizedBox(height: 10),
              _topTalkers(activeHotspot),
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


  Widget _securityScore(AsyncValue<List<Map<String, String>>> servicesAsync, AsyncValue<List<FirewallRule>> firewallAsync) {
    return servicesAsync.when(
      loading: () => _panelMessage(Icons.shield_outlined, 'جارٍ فحص خدمات الإدارة...', AppColors.textMuted),
      error: (_, __) => _panelMessage(Icons.info_outline_rounded, 'تعذر قراءة خدمات الراوتر؛ لم يتم احتساب المؤشر.', AppColors.warning),
      data: (services) {
        if (!firewallAsync.hasValue) return _panelMessage(Icons.info_outline_rounded, 'تعذر التأكد من قواعد الفايروول؛ لم يتم احتساب مؤشر الأمان.', AppColors.warning);
        final rules = firewallAsync.value ?? <FirewallRule>[];
        if (services.isEmpty) return _panelMessage(Icons.info_outline_rounded, 'بيانات خدمات الإدارة غير متاحة؛ المؤشر غير مكتمل.', AppColors.warning);
        bool enabled(String name) => services.any((s) => (s['name'] ?? '').toLowerCase() == name && !['yes', 'true'].contains((s['disabled'] ?? 'no').toLowerCase()));
        final activeRules = rules.where((r) => !r.disabled).toList();
        final hasInputProtection = activeRules.any((r) => r.chain.toLowerCase() == 'input' && ['drop', 'reject'].contains(r.action.toLowerCase()));
        final findings = <({String title, String detail, int penalty})>[];
        if (enabled('telnet')) findings.add((title: 'خدمة Telnet مفعّلة', detail: 'Telnet غير مشفّر؛ عطّلها إذا لم تكن تحتاجها.', penalty: 25));
        if (enabled('ftp')) findings.add((title: 'خدمة FTP مفعّلة', detail: 'راجع الحاجة إليها وقيّد الوصول إليها.', penalty: 15));
        if (enabled('api')) findings.add((title: 'واجهة API غير المشفّرة مفعّلة', detail: 'تحقق من تقييد الوصول إلى المنفذ 8728.', penalty: 10));
        if (activeRules.isEmpty) {
          findings.add((title: 'لا توجد قواعد Firewall مفعّلة', detail: 'لم تُكتشف قواعد فلترة فعّالة في القائمة المقروءة.', penalty: 30));
        } else if (!hasInputProtection) {
          findings.add((title: 'لم تُكتشف قاعدة إسقاط في input', detail: 'قد تكون الحماية موجودة في موضع آخر؛ راجع ترتيب القواعد يدويًا.', penalty: 20));
        }
        final score = (100 - findings.fold<int>(0, (sum, f) => sum + f.penalty)).clamp(0, 100);
        final color = score >= 80 ? AppColors.success : score >= 55 ? AppColors.warning : AppColors.danger;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 76, height: 76, child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: score / 100, strokeWidth: 7, backgroundColor: Colors.white.withOpacity(.07), valueColor: AlwaysStoppedAnimation<Color>(color))),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$score', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)), const Text('/100', style: TextStyle(color: AppColors.textMuted, fontSize: 9))]),
              ])),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(score >= 80 ? 'مستوى جيد مبدئيًا' : score >= 55 ? 'يحتاج مراجعة' : 'مخاطر تحتاج انتباه', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('تقييم أولي من الخدمات وقواعد الفلترة المقروءة، وليس فحصًا أمنيًا شاملًا.', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4)),
              ])),
            ]),
            const SizedBox(height: 14),
            if (findings.isEmpty)
              const Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18), SizedBox(width: 8), Expanded(child: Text('لم تُكتشف المشكلات المحددة في هذا الفحص.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)))])
            else
              ...findings.map((f) => Padding(padding: const EdgeInsets.only(top: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 17), const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(f.detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.35))])),
                Text('-${f.penalty}', style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800)),
              ]))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => context.push('/firewall'), icon: const Icon(Icons.tune_rounded, size: 16), label: const Text('مراجعة قواعد الجدار الناري')),
          ]),
        );
      },
    );
  }

  Widget _trafficFlow(List<InterfaceInfo> interfaces) {
    final rows = interfaces.where((e) => !e.disabled).toList()..sort((a, b) => (b.rxByte + b.txByte).compareTo(a.rxByte + a.txByte));
    final visible = rows.take(4).toList();
    if (visible.isEmpty || visible.every((e) => e.rxByte == 0 && e.txByte == 0)) {
      return _panelMessage(Icons.account_tree_rounded, 'لا توجد عدادات حركة مرور متاحة للعرض بعد. قد لا يدعم البروتوكول الحالي هذه القراءة.', AppColors.textMuted);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('توزيع عدادات RX / TX التراكمية حسب الواجهة', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
        const SizedBox(height: 8),
        SizedBox(height: 190, width: double.infinity, child: CustomPaint(painter: _TrafficSankeyPainter(visible, AppColors.primary, AppColors.secondary, AppColors.textMuted))),
        const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('القيم عدادات تراكمية منذ تصفيرها في الراوتر، وليست سرعة لحظية.', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5))),
      ]),
    );
  }

  Widget _topTalkers(List<Map<String, String>> hotspot) {
    final totals = <String, int>{};
    final rx = <String, int>{};
    final tx = <String, int>{};
    int counter(Map<String, String> row, List<String> keys) {
      for (final key in keys) {
        final value = int.tryParse(row[key] ?? '');
        if (value != null) return value;
      }
      return 0;
    }
    for (final row in hotspot) {
      final name = row['user'] ?? row['name'] ?? row['login'] ?? '';
      if (name.isEmpty) continue;
      final down = counter(row, ['bytes-in', 'rx-byte', 'bytesIn']);
      final up = counter(row, ['bytes-out', 'tx-byte', 'bytesOut']);
      rx[name] = (rx[name] ?? 0) + down;
      tx[name] = (tx[name] ?? 0) + up;
      totals[name] = (totals[name] ?? 0) + down + up;
    }
    final sorted = totals.keys.toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final usable = sorted.where((name) => totals[name]! > 0).take(5).toList();
    if (usable.isEmpty) return _panelMessage(Icons.leaderboard_rounded, 'عدادات الاستهلاك لكل جلسة غير متاحة من بيانات الراوتر الحالية؛ لن نعرض ترتيبًا تخمينيًا.', AppColors.textMuted);
    final maxValue = totals[usable.first]!.toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        ...usable.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final name = entry.value;
          final amount = totals[name]!;
          final color = rank == 1 ? AppColors.accent : rank == 2 ? AppColors.primary : AppColors.secondary;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
            Container(width: 27, height: 27, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(9)), child: Text('$rank', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900))),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: (amount / maxValue).clamp(0.0, 1.0).toDouble(), minHeight: 5, backgroundColor: Colors.white.withOpacity(.06), valueColor: AlwaysStoppedAnimation<Color>(color))),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_bytes(amount), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
              Text('↓ ${_bytes(rx[name] ?? 0)}  ↑ ${_bytes(tx[name] ?? 0)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 8.5)),
            ]),
          ]));
        }),
        const Divider(color: AppColors.border, height: 18),
        const Text('الترتيب حسب عدادات جلسات Hotspot النشطة التي يعيدها الراوتر؛ لا يمثل الاستهلاك اليومي ما لم تُصفّر العدادات يوميًا.', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, height: 1.4)),
      ]),
    );
  }

  Widget _panelMessage(IconData icon, String message, Color color) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.45)))]),
  );

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

class _TrafficSankeyPainter extends CustomPainter {
  _TrafficSankeyPainter(this.interfaces, this.rxColor, this.txColor, this.labelColor);
  final List<InterfaceInfo> interfaces;
  final Color rxColor;
  final Color txColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (interfaces.isEmpty) return;
    var maxBytes = 1;
    for (final e in interfaces) {
      if (e.rxByte > maxBytes) maxBytes = e.rxByte;
      if (e.txByte > maxBytes) maxBytes = e.txByte;
    }
    final labelStyle = TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w600);
    final rxStyle = TextStyle(color: rxColor, fontSize: 10, fontWeight: FontWeight.w700);
    final txStyle = TextStyle(color: txColor, fontSize: 10, fontWeight: FontWeight.w700);
    final leftX = size.width * .02;
    final midX = size.width * .42;
    final rightX = size.width * .76;
    final rowH = size.height / (interfaces.length + 1);
    for (var i = 0; i < interfaces.length; i++) {
      final item = interfaces[i];
      final y = rowH * (i + 1);
      final rxWidth = 2.0 + 11.0 * item.rxByte / maxBytes;
      final txWidth = 2.0 + 11.0 * item.txByte / maxBytes;
      final start = Offset(leftX + size.width * .24, y);
      final rxEnd = Offset(rightX, size.height * .35);
      final txEnd = Offset(rightX, size.height * .72);
      final rxPaint = Paint()..color = rxColor.withOpacity(.42)..style = PaintingStyle.stroke..strokeWidth = rxWidth..strokeCap = StrokeCap.round;
      final txPaint = Paint()..color = txColor.withOpacity(.42)..style = PaintingStyle.stroke..strokeWidth = txWidth..strokeCap = StrokeCap.round;
      final rxPath = Path()..moveTo(start.dx, start.dy)..cubicTo(midX, y, midX, rxEnd.dy, rxEnd.dx, rxEnd.dy);
      final txPath = Path()..moveTo(start.dx, start.dy)..cubicTo(midX, y, midX, txEnd.dy, txEnd.dx, txEnd.dy);
      canvas.drawPath(rxPath, rxPaint);
      canvas.drawPath(txPath, txPaint);
      _drawText(canvas, item.name, Offset(leftX, y - 7), labelStyle, maxWidth: size.width * .22);
    }
    _drawText(canvas, 'RX ↓', Offset(rightX + 4, size.height * .35 - 7), rxStyle, maxWidth: size.width * .2);
    _drawText(canvas, 'TX ↑', Offset(rightX + 4, size.height * .72 - 7), txStyle, maxWidth: size.width * .2);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {required double maxWidth}) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.rtl, maxLines: 1, ellipsis: '…')..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrafficSankeyPainter oldDelegate) =>
      oldDelegate.interfaces != interfaces || oldDelegate.rxColor != rxColor || oldDelegate.txColor != txColor;
}
