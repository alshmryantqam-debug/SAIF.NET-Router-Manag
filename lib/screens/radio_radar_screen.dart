import 'dart:convert';
import 'dart:io';

import 'package:dart_snmp/dart_snmp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class RadioRadarScreen extends ConsumerStatefulWidget {
  const RadioRadarScreen({super.key});
  @override
  ConsumerState<RadioRadarScreen> createState() => _RadioRadarScreenState();
}

class _RadioRadarScreenState extends ConsumerState<RadioRadarScreen> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'saifnet.radio_radar.targets';
  final _targets = <Map<String, String>>[];
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _community = TextEditingController(text: 'public');
  final _oid = TextEditingController();
  String _vendor = 'Ubiquiti';
  bool _loading = false;
  String? _error;
  List<Map<String, String>> _radios = [];
  List<Map<String, String>> _neighbors = [];
  List<Map<String, String>> _leases = [];
  List<Map<String, String>> _arp = [];
  DateTime? _updated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTargets();
      await _refresh();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _community.dispose();
    _oid.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw);
      if (data is List) {
        setState(() {
          _targets
            ..clear()
            ..addAll(data.whereType<Map>().map((e) =>
                Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString())))));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTargets() async {
    await _storage.write(key: _key, value: jsonEncode(_targets));
  }

  Future<void> _refresh() async {
    final service = ref.read(mikrotikProvider);
    if (!service.isConnected) {
      if (mounted) setState(() => _error = 'اتصل بالراوتر أولاً لعرض بيانات الرادار.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        service.runCommand('/interface/wireless/registration-table'),
        service.runCommand('/interface/wifi/registration-table'),
        service.runCommand('/ip/neighbor'),
        service.runCommand('/ip/dhcp-server/lease'),
        service.runCommand('/ip/arp'),
      ]);
      final merged = <Map<String, String>>[];
      final seen = <String>{};
      for (var i = 0; i < 2; i++) {
        for (final row in results[i]) {
          final mac = row['mac-address'] ?? row['mac-addresses'] ?? '';
          final key = '$mac-${row['interface'] ?? ''}';
          if (mac.isNotEmpty && seen.add(key)) merged.add({...row, '_source': i == 0 ? 'Wireless' : 'WiFi'});
        }
      }
      if (!mounted) return;
      setState(() {
        _radios = merged;
        _neighbors = results[2];
        _leases = results[3];
        _arp = results[4];
        _updated = DateTime.now();
      });
      for (final target in List<Map<String, String>>.from(_targets)) {
        await _readSnmp(target);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة بيانات الرادار: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _signal(Map<String, String> row) {
    final value = row['signal-strength'] ?? row['signal'] ?? '';
    final match = RegExp(r'-?\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  List<Map<String, String>> _networkDevices() {
    final devices = <String, Map<String, String>>{};

    void add(Map<String, String> row, String source) {
      final mac = (row['mac-address'] ?? row['mac-addresses'] ?? '').trim().toUpperCase();
      final ip = (row['address'] ?? row['ip-address'] ?? '').trim();
      final key = mac.isNotEmpty ? mac : ip;
      if (key.isEmpty) return;
      final existing = devices[key] ?? <String, String>{};
      devices[key] = {
        ...existing,
        ...row,
        if (mac.isNotEmpty) 'mac-address': mac,
        if (ip.isNotEmpty) 'address': ip,
        '_source': source,
      };
    }

    for (final row in _neighbors) {
      add(row, 'جار MikroTik');
    }
    for (final row in _leases) {
      add(row, 'DHCP');
    }
    for (final row in _arp) {
      add(row, 'ARP');
    }
    for (final row in _radios) {
      add(row, 'عميل لاسلكي مسجل');
    }
    final result = devices.values.toList();
    result.sort((a, b) {
      final aSignal = _signal(a);
      final bSignal = _signal(b);
      if (aSignal != null && bSignal == null) return -1;
      if (aSignal == null && bSignal != null) return 1;
      if (aSignal != null && bSignal != null) return aSignal.compareTo(bSignal);
      return (a['host-name'] ?? a['identity'] ?? a['address'] ?? '')
          .compareTo(b['host-name'] ?? b['identity'] ?? b['address'] ?? '');
    });
    return result;
  }

  Future<void> _addTarget() async {
    _name.clear(); _host.clear(); _oid.clear(); _community.text = 'public'; _vendor = 'Ubiquiti';
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('إضافة صحن عبر SNMP'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الصحن/القطاع')),
          TextField(controller: _host, decoration: const InputDecoration(labelText: 'عنوان IPv4'), keyboardType: TextInputType.number),
          DropdownButtonFormField<String>(
            value: _vendor,
            decoration: const InputDecoration(labelText: 'الشركة'),
            items: const [
              DropdownMenuItem(value: 'Ubiquiti', child: Text('Ubiquiti airOS')),
              DropdownMenuItem(value: 'Mimosa', child: Text('Mimosa')),
              DropdownMenuItem(value: 'MikroTik', child: Text('MikroTik')),
              DropdownMenuItem(value: 'Generic', child: Text('OID مخصص')),
            ],
            onChanged: (v) => setDialog(() {
              _vendor = v ?? 'Generic';
              _oid.text = _vendor == 'Mimosa' ? '1.3.6.1.4.1.43356.2.1.2.6.6' : '';
            }),
          ),
          TextField(controller: _community, decoration: const InputDecoration(labelText: 'SNMP community للقراءة فقط')),
          TextField(controller: _oid, decoration: const InputDecoration(labelText: 'OID رقمي لقوة الإشارة')),
          const SizedBox(height: 8),
          const Text('هذا يختبر OID واحداً فقط ولا يكتشف كل العملاء تلقائياً. SNMP v2c غير مشفر؛ استخدم شبكة إدارة موثوقة وبيانات قراءة فقط.', style: TextStyle(color: AppColors.warning, fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            final ip = InternetAddress.tryParse(_host.text.trim());
            final oid = _oid.text.trim().replaceFirst(RegExp(r'^\.'), '');
            if (_name.text.trim().isEmpty || ip == null || ip.type != InternetAddressType.IPv4 ||
                _community.text.trim().isEmpty || !RegExp(r'^\d+(\.\d+)+$').hasMatch(oid)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الاسم وعنوان IPv4 وCommunity وOID')));
              return;
            }
            final target = <String, String>{
              'name': _name.text.trim(), 'host': ip.address, 'community': _community.text.trim(),
              'oid': oid, 'vendor': _vendor,
            };
            setState(() {
              _targets.removeWhere((e) => e['host'] == ip.address);
              _targets.add(target);
            });
            Navigator.pop(ctx);
            await _saveTargets();
            await _readSnmp(target);
          }, child: const Text('حفظ واختبار')),
        ],
      ),
    ));
  }

  Future<void> _readSnmp(Map<String, String> target) async {
    try {
      final session = await Snmp.createSession(
        InternetAddress(target['host']!), community: target['community']!,
        port: 161, retries: 1, timeout: const Duration(seconds: 3), version: SnmpVersion.v2c,
      );
      try {
        final response = await session.get(Oid.fromString(target['oid']!));
        if (response.pdu.varbinds.isEmpty) throw Exception('No value');
        final rawText = response.pdu.varbinds.first.value.toString();
        final raw = double.tryParse(rawText.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        if (raw == null) throw Exception('Non-numeric value');
        final signal = target['vendor'] == 'Mimosa' &&
                target['oid'] == '1.3.6.1.4.1.43356.2.1.2.6.6' ? raw / 10 : raw;
        if (!mounted) return;
        setState(() {
          final i = _targets.indexWhere((e) => e['host'] == target['host']);
          if (i >= 0) _targets[i] = {..._targets[i], 'signal': signal.toStringAsFixed(1), 'error': ''};
        });
      } finally { session.close(); }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _targets.indexWhere((e) => e['host'] == target['host']);
        if (i >= 0) _targets[i] = {..._targets[i], 'error': 'فشل SNMP: تحقق من التفعيل وOID وCommunity'};
      });
    }
    await _saveTargets();
  }

  @override
  Widget build(BuildContext context) {
    final weak = _radios.where((r) { final s = _signal(r); return s != null && s < -78; }).length;
    return Scaffold(
      appBar: AppBar(title: const Text('رادار صحون البث'), actions: [
        IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
        IconButton(onPressed: _addTarget, icon: const Icon(Icons.add_link_rounded)),
      ]),
      body: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مراقبة الإشارة اللاسلكية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text('عملاء مسجلون: ${_radios.length}  •  إشارة أضعف من -78 dBm: $weak', style: const TextStyle(color: Colors.white)),
            if (_updated != null) Text('آخر تحديث: ${TimeOfDay.fromDateTime(_updated!).format(context)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: AppColors.warning)))),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        const Text('عملاء MikroTik اللاسلكيون', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (_radios.isEmpty && !_loading) const _InfoTile('لا توجد بيانات تسجيل؛ تحقق من الاتصال أو دعم واجهة wireless/wifi.'),
        ..._radios.map((row) {
          final signal = _signal(row);
          final weakSignal = signal != null && signal < -78;
          final color = weakSignal ? AppColors.danger : AppColors.success;
          return Card(
            color: weakSignal ? AppColors.danger.withOpacity(.1) : AppColors.bgCard,
            child: ListTile(
              leading: Icon(Icons.settings_input_antenna_rounded, color: color),
              title: Text(row['radio-name'] ?? row['mac-address'] ?? row['mac-addresses'] ?? 'جهاز لاسلكي'),
              subtitle: Text('${row['interface'] ?? '—'} • MAC ${row['mac-address'] ?? row['mac-addresses'] ?? '—'}\nTX/RX: ${row['tx-rate'] ?? '—'} / ${row['rx-rate'] ?? '—'}'),
              isThreeLine: true,
              trailing: Text(signal == null ? '—' : '$signal dBm', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const SizedBox(height: 18),
        Text('كل الأجهزة المكتشفة (${_networkDevices().length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('دمج من جدول اللاسلكي والجيران وDHCP وARP؛ تظهر الإشارة فقط عندما يزوّد MikroTik بقيمة فعلية.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ..._networkDevices().map((device) {
          final signal = _signal(device);
          final weakSignal = signal != null && signal < -78;
          final color = weakSignal ? AppColors.danger : (signal == null ? AppColors.textSecondary : AppColors.success);
          final name = device['host-name']?.isNotEmpty == true
              ? device['host-name']!
              : device['identity']?.isNotEmpty == true
                  ? device['identity']!
                  : device['radio-name']?.isNotEmpty == true
                      ? device['radio-name']!
                      : device['address'] ?? device['mac-address'] ?? 'جهاز شبكة';
          return Card(
            color: weakSignal ? AppColors.danger.withOpacity(.12) : AppColors.bgCard,
            child: ListTile(
              leading: Icon(weakSignal ? Icons.signal_wifi_bad_rounded : Icons.devices_other_rounded, color: color),
              title: Text(name),
              subtitle: Text('${device['address'] ?? 'IP غير معروف'} • ${device['mac-address'] ?? 'MAC غير معروف'}\nالمصدر: ${device['_source'] ?? 'اكتشاف الشبكة'}'),
              isThreeLine: true,
              trailing: Text(signal == null ? 'الإشارة غير متاحة' : '${signal} dBm',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        }),
        const SizedBox(height: 18),
        Text('أجهزة SNMP المضافة (${_targets.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ..._targets.map((target) {
          final signal = double.tryParse(target['signal'] ?? '');
          final weakSignal = signal != null && signal < -78;
          final color = weakSignal ? AppColors.danger : AppColors.success;
          return Card(
            color: weakSignal ? AppColors.danger.withOpacity(.1) : AppColors.bgCard,
            child: ListTile(
              leading: Icon(Icons.router_rounded, color: color),
              title: Text(target['name'] ?? target['host'] ?? 'Radio'),
              subtitle: Text(target['error']?.isNotEmpty == true ? target['error']! : '${target['host']} • ${target['vendor']}'),
              trailing: signal == null ? IconButton(onPressed: () => _readSnmp(target), icon: const Icon(Icons.refresh)) : Text('${signal.toStringAsFixed(1)} dBm', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              onTap: () => _readSnmp(target),
            ),
          );
        }),
        const SizedBox(height: 16),
        Text('الجيران المكتشفون: ${_neighbors.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ..._neighbors.take(25).map((r) => ListTile(leading: const Icon(Icons.hub_rounded), title: Text(r['identity'] ?? r['address'] ?? 'جهاز'), subtitle: Text('${r['address'] ?? ''} • ${r['mac-address'] ?? ''}'))),
        const SizedBox(height: 16),
        Text('عناوين DHCP: ${_leases.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ..._leases.take(25).map((r) => ListTile(leading: const Icon(Icons.devices_rounded), title: Text(r['host-name']?.isNotEmpty == true ? r['host-name']! : r['address'] ?? 'جهاز'), subtitle: Text('${r['address'] ?? ''} • ${r['mac-address'] ?? ''}'))),
        const SizedBox(height: 12),
        const _InfoTile('الإشارة الأقل من -78 dBm تظهر باللون الأحمر كتنبيه أولي. ضعف الإشارة وحده لا يثبت بطء القطاع. أجهزة Ubiquiti وMimosa تحتاج OID صحيحاً لكل موديل، وهذه النسخة لا تسوي walk تلقائياً لجدول كل عميل.'),
      ])),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
