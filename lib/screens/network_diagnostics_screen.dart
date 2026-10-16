import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../models/network_alert_engine.dart';
import '../theme.dart';

class NetworkDiagnosticsScreen extends ConsumerWidget {
  const NetworkDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interfaces = ref.watch(interfacesProvider);
    final interfaceMembers = ref.watch(interfaceListMembersProvider);
    final wanTraffic = ref.watch(wanTrafficProvider);
    final resource = ref.watch(resourceProvider);
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
      for (final p in [
        interfacesProvider,
        interfaceListMembersProvider,
        wanTrafficProvider,
        resourceProvider,
        hotspotActiveProvider,
        pppActiveProvider,
        dhcpLeasesProvider,
        simpleQueuesProvider,
        ipAddressesProvider,
        firewallFilterProvider,
        firewallNatProvider,
        firewallMangleProvider,
        routesProvider,
        logsProvider,
      ]) {
        ref.invalidate(p);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز مراقبة الشبكة'),
        actions: [
          IconButton(tooltip: 'تحديث القراءات', onPressed: refresh, icon: const Icon(Icons.refresh_rounded)),
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
                Row(children: [
                  Icon(Icons.monitor_heart_rounded, color: AppTheme.primary, size: 26),
                  SizedBox(width: 10),
                  Expanded(child: Text('نظرة شاملة على الشبكة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
                ]),
                SizedBox(height: 8),
                Text('قراءات مباشرة من RouterOS — وضع القراءة فقط.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (interfaces.hasValue && interfaceMembers.hasValue && resource.hasValue)
            _AlertPanel(
              alerts: NetworkAlertEngine.evaluate(
                interfaces: interfaces.valueOrNull ?? const [],
                interfaceListMembers: interfaceMembers.valueOrNull ?? const [],
                cpuPercent: int.tryParse((resource.valueOrNull as Map?)?['cpu-load']?.toString() ?? ''),
                memoryPercent: _memoryPercent(resource.valueOrNull),
                temperatureCelsius: int.tryParse((resource.valueOrNull as Map?)?['cpu-temperature']?.toString() ?? ''),
              ),
            )
          else
            const _AlertUnavailable(),
          const SizedBox(height: 12),
          _TrafficPanel(data: wanTraffic),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _CountCard(title: 'واجهات نشطة', icon: Icons.lan_rounded, value: interfaces, runningOnly: true)),
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
          _DataSection(title: 'جلسات Hotspot', icon: Icons.wifi_outlined, data: hotspot, fields: const ['user', 'address', 'mac-address', 'uptime', 'server']),
          _DataSection(title: 'جلسات PPPoE', icon: Icons.cable_outlined, data: ppp, fields: const ['name', 'service', 'caller-id', 'address', 'uptime']),
          _DataSection(title: 'عقود DHCP', icon: Icons.devices_outlined, data: leases, fields: const ['address', 'mac-address', 'host-name', 'status', 'server']),
          _DataSection(title: 'Simple Queues', icon: Icons.speed_rounded, data: queues, fields: const ['name', 'target', 'max-limit', 'disabled', 'comment']),
          _DataSection(title: 'عناوين IP', icon: Icons.public_rounded, data: addresses, fields: const ['address', 'network', 'interface', 'disabled']),
          _DataSection(title: 'المسارات', icon: Icons.alt_route_rounded, data: routes, fields: const ['dst-address', 'gateway', 'distance', 'active', 'disabled']),
          _DataSection(title: 'Firewall Filter', icon: Icons.shield_outlined, data: filter, fields: const ['chain', 'action', 'protocol', 'src-address', 'dst-address', 'disabled', 'comment']),
          _DataSection(title: 'Firewall NAT', icon: Icons.swap_horiz_rounded, data: nat, fields: const ['chain', 'action', 'protocol', 'to-addresses', 'disabled', 'comment']),
          _DataSection(title: 'Firewall Mangle', icon: Icons.tune_rounded, data: mangle, fields: const ['chain', 'action', 'protocol', 'disabled', 'comment']),
          _DataSection(title: 'سجل النظام', icon: Icons.receipt_long_rounded, data: logs, fields: const ['time', 'topics', 'message'], redactMessage: true),
        ],
      ),
    );
  }
}

int? _memoryPercent(dynamic resource) {
  if (resource is! Map) return null;
  final total = int.tryParse(resource['total-memory']?.toString() ?? '');
  final free = int.tryParse(resource['free-memory']?.toString() ?? '');
  if (total == null || free == null || total <= 0 || free < 0 || free > total) return null;
  return (((total - free) / total) * 100).round();
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
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(height: 5),
            value.when(
              loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const Text('—', style: TextStyle(color: AppTheme.textMuted, fontSize: 20, fontWeight: FontWeight.w900)),
              data: (rows) {
                final count = runningOnly
                    ? rows.where((r) => r is Map && ['true', 'yes'].contains(r['running']?.toString().toLowerCase())).length
                    : rows.length;
                return Text('$count', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900));
              },
            ),
          ]),
        ),
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
        loading: () => ListTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          trailing: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => ListTile(
          leading: const Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          subtitle: Text('تعذّر التحميل: ${error.toString().replaceAll('Exception: ', '')}',
              maxLines: 2, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ),
        data: (rows) => ExpansionTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          subtitle: Text('${rows.length} سجل', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          children: rows.isEmpty
              ? const [Padding(padding: EdgeInsets.all(16), child: Text('لا توجد سجلات.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)))]
              : rows.take(80).map((row) {
                  if (row is! Map) return const SizedBox.shrink();
                  final map = Map<String, dynamic>.from(row);
                  final visible = fields.where((f) => map[f] != null && map[f].toString().isNotEmpty).toList();
                  if (visible.isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.6)))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: visible
                          .map((field) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  SizedBox(width: 100, child: Text(field, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
                                  Expanded(child: Text(_safe(map[field]), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                                ]),
                              ))
                          .toList(),
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }
}

class _AlertUnavailable extends StatelessWidget {
  const _AlertUnavailable();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
        child: const Row(children: [
          Icon(Icons.hourglass_top_rounded, color: AppTheme.textMuted),
          SizedBox(width: 10),
          Expanded(child: Text('جارٍ جمع بيانات الشبكة…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
        ]),
      );
}

class _AlertPanel extends StatelessWidget {
  final List<NetworkAlert> alerts;
  const _AlertPanel({required this.alerts});

  Color _color(NetworkAlertSeverity s) {
    switch (s) {
      case NetworkAlertSeverity.info:
        return AppTheme.primary;
      case NetworkAlertSeverity.warning:
        return AppTheme.warning;
      case NetworkAlertSeverity.critical:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final critical = alerts.where((a) => a.severity == NetworkAlertSeverity.critical).length;
    final warnings = alerts.where((a) => a.severity == NetworkAlertSeverity.warning).length;
    final color = critical > 0 ? AppTheme.danger : warnings > 0 ? AppTheme.warning : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.notifications_active_outlined, color: color, size: 21),
          const SizedBox(width: 8),
          const Expanded(child: Text('تنبيهات الشبكة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900))),
          Text('$critical حرج · $warnings تحذير', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
        if (alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('لا توجد تنبيهات حسب القراءات الحالية.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          )
        else
          ...alerts.take(6).map((a) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${a.title}: ${a.detail}', style: TextStyle(color: _color(a.severity), fontSize: 11, height: 1.4)),
              )),
      ]),
    );
  }
}

String _formatBitRate(dynamic raw) {
  final value = double.tryParse(raw?.toString() ?? '');
  if (value == null || value < 0) return '—';
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)} Gbps';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)} Mbps';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)} kbps';
  return '${value.toStringAsFixed(0)} bps';
}

class _TrafficPanel extends StatelessWidget {
  final AsyncValue<List<dynamic>> data;
  const _TrafficPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.speed_rounded, color: AppTheme.primary, size: 21),
          SizedBox(width: 8),
          Expanded(child: Text('حركة خطوط WAN', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        data.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const Text('تعذّر قراءة معدل الحركة.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          data: (rows) {
            if (rows.isEmpty) {
              return const Text('لا توجد واجهات WAN أو عينة حركة.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11));
            }
            return Column(
              children: rows.whereType<Map>().map((row) {
                final name = row['name']?.toString() ?? '—';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))),
                    Text('↓ ${_formatBitRate(row['rx-bits-per-second'])}', style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
                    const SizedBox(width: 12),
                    Text('↑ ${_formatBitRate(row['tx-bits-per-second'])}', style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}
