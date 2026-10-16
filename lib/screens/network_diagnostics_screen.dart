import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class NetworkDiagnosticsScreen extends ConsumerWidget {
  const NetworkDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interfaces = ref.watch(interfacesProvider);
    final hotspot = ref.watch(hotspotActiveProvider);
    final ppp = ref.watch(pppActiveProvider);
    final leases = ref.watch(dhcpLeasesProvider);
    final queues = ref.watch(simpleQueuesProvider);
    final addresses = ref.watch(ipAddressesProvider);
    final filter = ref.watch(firewallFilterProvider);
    final nat = ref.watch(firewallNatProvider);
    final mangle = ref.watch(firewallMangleProvider);
    final routes = ref.watch(routesProvider);
    final logs = ref.watch(logsProvider);

    void refresh() {
      ref.invalidate(interfacesProvider);
      ref.invalidate(hotspotActiveProvider);
      ref.invalidate(pppActiveProvider);
      ref.invalidate(dhcpLeasesProvider);
      ref.invalidate(simpleQueuesProvider);
      ref.invalidate(ipAddressesProvider);
      ref.invalidate(firewallFilterProvider);
      ref.invalidate(firewallNatProvider);
      ref.invalidate(firewallMangleProvider);
      ref.invalidate(routesProvider);
      ref.invalidate(logsProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز مراقبة الشبكة'),
        actions: [
          IconButton(
            tooltip: 'تحديث القراءات',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withOpacity(0.24)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart_rounded, color: AppTheme.primary, size: 26),
                    SizedBox(width: 10),
                    Expanded(child: Text('نظرة شاملة على الشبكة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
                  ],
                ),
                SizedBox(height: 8),
                Text('قراءات مباشرة من RouterOS؛ كل قسم يعرض خطأ الصلاحية أو الاتصال بدلاً من اختلاق بيانات.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6)),
                SizedBox(height: 8),
                Text('وضع القراءة فقط — لا تُنفّذ هذه الشاشة أي تغييرات على الراوتر.', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _CountCard(title: 'واجهات الشبكة', icon: Icons.lan_rounded, value: interfaces, runningOnly: true)),
            const SizedBox(width: 10),
            Expanded(child: _CountCard(title: 'Hotspot نشط', icon: Icons.wifi_rounded, value: hotspot)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _CountCard(title: 'PPPoE نشط', icon: Icons.cable_rounded, value: ppp)),
            const SizedBox(width: 10),
            Expanded(child: _CountCard(title: 'DHCP leases', icon: Icons.devices_rounded, value: leases)),
          ]),
          const SizedBox(height: 20),
          const Text('تفاصيل الشبكة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _DataSection(title: 'واجهات الشبكة', icon: Icons.lan_outlined, data: interfaces, fields: const ['name', 'type', 'running', 'disabled', 'mac-address', 'mtu', 'comment']),
          _DataSection(title: 'جلسات Hotspot النشطة', icon: Icons.wifi_outlined, data: hotspot, fields: const ['user', 'address', 'mac-address', 'uptime', 'server', 'bytes-in', 'bytes-out']),
          _DataSection(title: 'جلسات PPPoE النشطة', icon: Icons.cable_outlined, data: ppp, fields: const ['name', 'service', 'caller-id', 'address', 'uptime', 'encoding']),
          _DataSection(title: 'عقود DHCP', icon: Icons.devices_outlined, data: leases, fields: const ['address', 'mac-address', 'host-name', 'status', 'server', 'last-seen', 'comment']),
          _DataSection(title: 'Simple Queues', icon: Icons.speed_rounded, data: queues, fields: const ['name', 'target', 'max-limit', 'limit-at', 'priority', 'disabled', 'comment']),
          _DataSection(title: 'عناوين IP', icon: Icons.public_rounded, data: addresses, fields: const ['address', 'network', 'interface', 'disabled', 'dynamic']),
          _DataSection(title: 'المسارات Routes', icon: Icons.alt_route_rounded, data: routes, fields: const ['dst-address', 'gateway', 'distance', 'routing-table', 'active', 'disabled', 'comment']),
          _DataSection(title: 'Firewall Filter', icon: Icons.shield_outlined, data: filter, fields: const ['chain', 'action', 'protocol', 'src-address', 'dst-address', 'dst-port', 'in-interface', 'out-interface', 'disabled', 'packets', 'bytes', 'comment']),
          _DataSection(title: 'Firewall NAT', icon: Icons.swap_horiz_rounded, data: nat, fields: const ['chain', 'action', 'protocol', 'src-address', 'dst-address', 'dst-port', 'to-addresses', 'to-ports', 'disabled', 'packets', 'bytes', 'comment']),
          _DataSection(title: 'Firewall Mangle', icon: Icons.tune_rounded, data: mangle, fields: const ['chain', 'action', 'protocol', 'src-address', 'dst-address', 'new-connection-mark', 'new-routing-mark', 'new-packet-mark', 'disabled', 'packets', 'bytes', 'comment']),
          _DataSection(title: 'سجل النظام', icon: Icons.receipt_long_rounded, data: logs, fields: const ['time', 'topics', 'message'], redactMessage: true),
          const SizedBox(height: 12),
          const Text('تنبيه: بعض الأقسام تحتاج صلاحيات read المناسبة في RouterOS. لا تمنح حساب التطبيق صلاحيات write أو sensitive لمجرد عرض المراقبة.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.6)),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<dynamic>> value;
  final bool runningOnly;

  const _CountCard({required this.title, required this.icon, required this.value, this.runningOnly = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3)),
          const SizedBox(height: 5),
          value.when(
            loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Text('—', style: TextStyle(color: AppTheme.textMuted, fontSize: 20, fontWeight: FontWeight.w900)),
            data: (rows) {
              final count = runningOnly
                  ? rows.where((row) => row is Map && ['true', 'yes'].contains(row['running']?.toString().toLowerCase())).length
                  : rows.length;
              return Text('$count', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900));
            },
          ),
        ])),
      ]),
    );
  }
}

class _DataSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<dynamic>> data;
  final List<String> fields;
  final bool redactMessage;

  const _DataSection({required this.title, required this.icon, required this.data, required this.fields, this.redactMessage = false});

  String _safe(dynamic value) {
    var text = value?.toString() ?? '—';
    if (redactMessage) {
      text = text.replaceAll(
        RegExp(r'(?i)(password|secret|token|private[-_ ]?key|api[-_ ]?key)\s*[=:]\s*[^\s,;]+'),
        r'$1=[REDACTED]',
      );
    }
    if (text.length > 220) text = '${text.substring(0, 220)}…';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
      child: data.when(
        loading: () => ListTile(leading: Icon(icon, color: AppTheme.primary), title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)), trailing: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (error, _) => ListTile(
          leading: Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          subtitle: Text('تعذّر تحميل القسم: ${error.toString().replaceAll('Exception: ', '')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ),
        data: (rows) => ExpansionTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          subtitle: Text('${rows.length} سجل', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          children: rows.isEmpty
              ? const [Padding(padding: EdgeInsets.all(16), child: Text('لا توجد سجلات أو لا تتوفر بيانات.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)))]
              : rows.take(100).map((row) {
                  if (row is! Map) return const SizedBox.shrink();
                  final map = Map<String, dynamic>.from(row);
                  final visible = fields.where((field) => map.containsKey(field) && map[field] != null && map[field].toString().isNotEmpty).toList();
                  if (visible.isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.6)))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: visible.map((field) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 105, child: Text(field, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
                        Expanded(child: Text(_safe(map[field]), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4))),
                      ]),
                    )).toList()),
                  );
                }).toList(growable: false),
        ),
      ),
    );
  }
}
