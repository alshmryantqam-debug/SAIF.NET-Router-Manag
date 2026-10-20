import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hotspot_provider.dart';
import '../providers/subscribers_provider.dart';
import '../providers/traffic_provider.dart';
import '../widgets/glass_card.dart';
import 'hotspot_screen.dart';
import 'pppoe_screen.dart';

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
      context.read<TrafficProvider>().refreshInterfaces();
    });
  }

  @override
  void dispose() {
    context.read<DashboardProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<DashboardProvider>().fetchResources(),
      context.read<SubscribersProvider>().load(),
      context.read<HotspotProvider>().fetchUsers(),
      context.read<ConnectionProvider>().fetchInterfaces(),
      context.read<TrafficProvider>().refreshInterfaces(),
    ]);
  }

  void _openSection(int index, Widget fallback) {
    final callback = widget.onOpenSection;
    if (callback != null) {
      callback(index);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => fallback),
      );
    }
  }

  String _temperature(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'غير متاح') return 'غير متاح';
    final lower = text.toLowerCase();
    if (lower.endsWith('c') || lower.endsWith('°c') || lower.endsWith('f')) {
      return text;
    }
    final number = double.tryParse(text);
    return number == null ? text : '${number.toStringAsFixed(0)}°C';
  }

  String _speed(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)} Gbps';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} Mbps';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} Kbps';
    return '${value.toStringAsFixed(0)} bps';
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final traffic = context.watch<TrafficProvider>();
    final broadband = context.watch<SubscribersProvider>();
    final hotspot = context.watch<HotspotProvider>();

    final watchedName = traffic.watched.isEmpty ? null : traffic.watched.first;
    final hasWatched = watchedName != null &&
        traffic.interfaces.any((item) => item.name == watchedName);
    final selectedName = hasWatched
        ? watchedName
        : traffic.interfaces.isEmpty
            ? null
            : traffic.interfaces.first.name;
    final selectedItems = selectedName == null
        ? <RosInterface>[]
        : traffic.interfaces.where((item) => item.name == selectedName).toList();
    final selectedInterface = selectedItems.isEmpty ? null : selectedItems.first;
    final samples = selectedName == null
        ? const <TrafficSample>[]
        : traffic.history[selectedName] ?? const <TrafficSample>[];
    final latest = samples.isEmpty ? null : samples.last;
    final cpu = (double.tryParse(dashboard.cpuLoad) ?? 0).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.hub_rounded, color: NovaColors.primary, size: 25),
            SizedBox(width: 10),
            Text('NOVA'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: connection.isConnected ? _refresh : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: NovaColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: NovaColors.gradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: NovaColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          connection.routerIdentity.isEmpty
                              ? 'راوتر الشبكة'
                              : connection.routerIdentity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ConnectionBadge(connected: connection.isConnected),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dashboard.boardName == 'غير متصل'
                        ? 'معلومات الراوتر ستظهر بعد الاتصال'
                        : '${dashboard.boardName}'
                            '${dashboard.version.isEmpty ? '' : ' · RouterOS ${dashboard.version}'}',
                    style: const TextStyle(color: NovaColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: NovaColors.border,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'حالة الجهاز',
                    style: TextStyle(color: NovaColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.memory_rounded,
                          label: 'المعالج CPU',
                          value: '${cpu.toStringAsFixed(0)}%',
                          fill: cpu / 100,
                          color: cpu >= 85 ? NovaColors.danger : NovaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.device_thermostat_rounded,
                          label: 'حرارة الراوتر',
                          value: _temperature(dashboard.cpuTemperature),
                          fill: null,
                          color: NovaColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  if (dashboard.error != null && connection.isConnected) ...[
                    const SizedBox(height: 12),
                    Text(
                      dashboard.error!,
                      style: const TextStyle(color: NovaColors.warn, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionHeading(
              title: 'مراقبة خط الإنترنت',
              subtitle: 'اختر واجهة واحدة لمتابعة الرفع والتنزيل مباشرة',
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'واجهة المراقبة',
                      prefixIcon: Icon(Icons.cable_rounded),
                    ),
                    hint: const Text('اختر واجهة من الراوتر'),
                    items: traffic.interfaces
                        .map((item) => DropdownMenuItem<String>(
                              value: item.name,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: connection.isConnected
                        ? (value) {
                            if (value != null) {
                              traffic.selectInterface(value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 14),
                  if (!connection.isConnected)
                    const _EmptyHint(
                      icon: Icons.link_off_rounded,
                      text: 'اتصل بالراوتر لعرض سرعة الخط.',
                    )
                  else if (traffic.interfaces.isEmpty)
                    const _EmptyHint(
                      icon: Icons.cable_rounded,
                      text: 'لم تصل قائمة الواجهات بعد. اسحب للأسفل للتحديث.',
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _TrafficValue(
                            label: 'تنزيل',
                            value: latest == null ? 'جارٍ القياس…' : _speed(latest.rx),
                            icon: Icons.south_rounded,
                            color: NovaColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TrafficValue(
                            label: 'رفع',
                            value: latest == null ? 'جارٍ القياس…' : _speed(latest.tx),
                            icon: Icons.north_rounded,
                            color: NovaColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          selectedInterface?.running == true
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 17,
                          color: selectedInterface?.running == true
                              ? NovaColors.success
                              : NovaColors.warn,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            selectedInterface?.running == true
                                ? 'الواجهة تعمل'
                                : 'الواجهة غير نشطة أو لا يوجد رابط',
                            style: const TextStyle(
                              fontSize: 12,
                              color: NovaColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          samples.isEmpty ? '—' : 'مباشر',
                          style: const TextStyle(
                            color: NovaColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionHeading(
              title: 'إدارة المشتركين',
              subtitle: 'ادخل مباشرة إلى إدارة الحسابات، لا مجرد عرض الأرقام',
            ),
            const SizedBox(height: 10),
            _ManagementCard(
              title: 'برودباند',
              subtitle: 'PPPoE · حسابات المشتركين',
              icon: Icons.dns_rounded,
              total: broadband.all.length,
              active: broadband.onlineCount,
              color: NovaColors.primary,
              onTap: () => _openSection(2, const PppoeScreen()),
            ),
            const SizedBox(height: 10),
            _ManagementCard(
              title: 'هوتسبوت',
              subtitle: 'البطاقات والمستخدمون',
              icon: Icons.wifi_tethering_rounded,
              total: hotspot.users.length,
              active: hotspot.activeCount,
              color: NovaColors.cyan,
              onTap: () => _openSection(3, const HotspotScreen()),
            ),
            if (broadband.error != null || hotspot.error != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Text(
                  'تنبيه: بعض بيانات المشتركين لم تُحمّل. افتح القسم المعني أو حدّث البيانات وتحقق من صلاحيات API.',
                  style: const TextStyle(color: NovaColors.warn, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  const _ConnectionBadge({required this.connected});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: (connected ? NovaColors.success : NovaColors.danger).withOpacity(.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: (connected ? NovaColors.success : NovaColors.danger).withOpacity(.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? NovaColors.success : NovaColors.danger,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              connected ? 'متصل' : 'غير متصل',
              style: TextStyle(
                color: connected ? NovaColors.success : NovaColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? fill;
  final Color color;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.fill,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.surface2,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            if (fill != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 5,
                  backgroundColor: NovaColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
        ],
      );
}

class _TrafficValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _TrafficValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.surface2,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _ManagementCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int total;
  final int active;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.total,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NovaColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.13),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        'نشط $active من $total',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: NovaColors.muted, size: 28),
              ],
            ),
          ),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: NovaColors.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: NovaColors.muted))),
          ],
        ),
      );
}