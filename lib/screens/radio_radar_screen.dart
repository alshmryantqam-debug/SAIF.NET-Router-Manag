import 'dart:io';
import 'package:dart_snmp/dart_snmp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class RadioRadarScreen extends ConsumerStatefulWidget {
  const RadioRadarScreen({super.key});

  @override
  ConsumerState<RadioRadarScreen> createState() => _RadioRadarScreenState();
}

class _RadioRadarScreenState extends ConsumerState<RadioRadarScreen> {
  bool _loading = false;

  final _snmpTargets = <Map<String, String>>[];
  final _snmpName = TextEditingController();
  final _snmpHost = TextEditingController();
  final _snmpCommunity = TextEditingController(text: 'public');
  final _snmpOid = TextEditingController();
  String _snmpVendor = 'Ubiquiti';

  Future<void> _addSnmpDevice() async {
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('ربط جهاز لاسلكي عبر SNMP'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _snmpName, decoration: const InputDecoration(labelText: 'اسم الصحن')),
          TextField(controller: _snmpHost, decoration: const InputDecoration(labelText: 'IPv4 للجهاز'), keyboardType: TextInputType.number),
          DropdownButtonFormField<String>(
            value: _snmpVendor,
            decoration: const InputDecoration(labelText: 'الشركة'),
            items: const [
              DropdownMenuItem(value: 'Ubiquiti', child: Text('Ubiquiti airOS')),
              DropdownMenuItem(value: 'Mimosa', child: Text('Mimosa')),
              DropdownMenuItem(value: 'MikroTik', child: Text('MikroTik')),
              DropdownMenuItem(value: 'Generic', child: Text('OID مخصص')),
            ],
            onChanged: (v) => setDialog(() {
              _snmpVendor = v ?? 'Generic';
              if (_snmpVendor == 'Mimosa') _snmpOid.text = '1.3.6.1.4.1.43356.2.1.2.6.6';
              else if (_snmpVendor == 'Ubiquiti') _snmpOid.text = '1.3.6.1.4.1.41112.1.4.5.1.1.6.1';
              else _snmpOid.clear();
            }),
          ),
          TextField(controller: _snmpCommunity, decoration: const InputDecoration(labelText: 'SNMP Community قراءة فقط')),
          TextField(controller: _snmpOid, decoration: const InputDecoration(labelText: 'OID لقوة الإشارة')),
          const Text('SNMP v2c غير مشفر. استخدم Community قراءة فقط وعلى شبكة إدارة موثوقة. قد يختلف OID حسب الموديل والبرنامج.', style: TextStyle(color: AppColors.warning, fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            final ip = InternetAddress.tryParse(_snmpHost.text.trim());
            final oid = _snmpOid.text.trim().replaceFirst(RegExp(r'^\.'), '');
            if (_snmpName.text.trim().isEmpty || ip == null || ip.type != InternetAddressType.IPv4 || _snmpCommunity.text.trim().isEmpty || !RegExp(r'^\d+(\.\d+)+
  String? _error;
  List<Map<String, String>> _radios = [];
  List<Map<String, String>> _neighbors = [];
  List<Map<String, String>> _leases = [];
  DateTime? _updated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final service = ref.read(mikrotikProvider);
    if (!service.isConnected) {
      setState(() => _error = 'اتصل بالراوتر أولاً لعرض بيانات الرادار.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        service.runCommand('/interface/wireless/registration-table'),
        service.runCommand('/interface/wifi/registration-table'),
        service.runCommand('/ip/neighbor'),
        service.runCommand('/ip/dhcp-server/lease'),
      ]);
      final merged = <Map<String, String>>[];
      final seen = <String>{};
      for (var i = 0; i < 2; i++) {
        for (final row in results[i]) {
          final key = '${row['mac-address'] ?? row['mac-addresses'] ?? ''}-${row['interface'] ?? ''}';
          if (seen.add(key) && key != '-') {
            merged.add({...row, '_source': i == 0 ? 'Wireless' : 'WiFi'});
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _radios = merged;
        _neighbors = results[2];
        _leases = results[3];
        _updated = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة بعض بيانات الرادار: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _signal(Map<String, String> row) {
    final value = row['signal-strength'] ?? row['signal'] ?? '';
    final match = RegExp(r'-?\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final weak = _radios.where((r) {
      final s = _signal(r);
      return s != null && s < -78;
    }).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('رادار صحون البث'),
        actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded)), IconButton(onPressed: _addSnmpDevice, icon: const Icon(Icons.add_link_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مراقبة الإشارة اللاسلكية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 8),
                Text('المسجلون لاسلكياً: ${_radios.length}   •   إشارة ضعيفة: $weak', style: const TextStyle(color: Colors.white)),
                if (_updated != null) Text('آخر تحديث: ${TimeOfDay.fromDateTime(_updated!).format(context)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: const TextStyle(color: AppColors.warning)))),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('الأجهزة المسجلة لاسلكياً', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_radios.isEmpty && !_loading) const _InfoTile(text: 'لا توجد بيانات تسجيل لاسلكي. قد لا يدعم الراوتر هذا المسار أو قد لا توجد أجهزة متصلة لاسلكياً به.'),
            ..._radios.map(_radioCard),
            const SizedBox(height: 18),
            Text('الجيران المكتشفون (${_neighbors.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_neighbors.isEmpty) const _InfoTile(text: 'لا توجد أجهزة ظاهرة في جدول الجيران حالياً.'),
            ..._neighbors.take(30).map((r) => _simpleCard(r, 'Neighbor')),
            const SizedBox(height: 18),
            Text('عناوين DHCP (${_leases.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_leases.isEmpty) const _InfoTile(text: 'لا توجد سجلات DHCP متاحة عبر هذا الاتصال.'),
            ..._leases.take(30).map((r) => _simpleCard(r, 'DHCP')),
            const SizedBox(height: 18),
            Row(children: [const Expanded(child: Text('أجهزة SNMP اللاسلكية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))), IconButton(onPressed: _addSnmpDevice, icon: const Icon(Icons.add_circle_outline_rounded))]),
            ..._snmpTargets.map(_snmpDeviceCard),
            const SizedBox(height: 18),
            const _InfoTile(text: 'مهم: الرادار يقرأ بيانات MikroTik عبر API ويمكنه اختبار OID واحد لكل جهاز عبر SNMP v2c. يجب ضبط OID الصحيح حسب موديل Ubiquiti أو Mimosa، ولا يعني ذلك اكتشاف جميع العملاء تلقائياً.') أجهزة Ubiquiti وMimosa تحتاج ربط SNMP أو واجهة إدارتها حتى تظهر قوة إشارتها. جدول الجيران وDHCP لا يكشف كل أجهزة الشبكة، والإشارة الأضعف من ‎-78 dBm إنذار أولي وليست وحدها دليلاً أن القطاع كله بطيء.'),
          ],
        ),
      ),
    );
  }

  Widget _radioCard(Map<String, String> row) {
    final signal = _signal(row);
    final isWeak = signal != null && signal < -78;
    final color = isWeak ? AppColors.danger : AppColors.success;
    return Card(
      color: isWeak ? AppColors.danger.withOpacity(.10) : AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isWeak ? AppColors.danger : AppColors.border, width: isWeak ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.settings_input_antenna_rounded, color: color, size: 27),
            const SizedBox(width: 10),
            Expanded(child: Text(row['radio-name'] ?? row['mac-address'] ?? row['mac-addresses'] ?? 'جهاز لاسلكي', style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(signal == null ? 'غير معروف' : '$signal dBm', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text('الواجهة: ${row['interface'] ?? '—'}   •   النوع: ${row['_source'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('MAC: ${row['mac-address'] ?? row['mac-addresses'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('TX/RX: ${row['tx-rate'] ?? '—'} / ${row['rx-rate'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (isWeak) const Padding(padding: EdgeInsets.only(top: 8), child: Text('⚠ إشارة ضعيفة — افحص المحاذاة والتشويش ومعدل الإرسال', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _simpleCard(Map<String, String> row, String type) {
    final name = row['identity'] ?? row['host-name'] ?? row['address'] ?? row['mac-address'] ?? 'جهاز';
    final details = [row['address'], row['mac-address'], row['interface'], row['platform']].where((v) => v != null && v!.isNotEmpty).join(' • ');
    return Card(child: ListTile(leading: Icon(type == 'DHCP' ? Icons.devices_rounded : Icons.hub_rounded, color: AppColors.secondary), title: Text(name), subtitle: Text(details.isEmpty ? type : details)));
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
).hasMatch(oid)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الاسم وIPv4 وCommunity وOID')));
              return;
            }
            final device = <String, String>{'name': _snmpName.text.trim(), 'host': ip.address, 'community': _snmpCommunity.text.trim(), 'oid': oid, 'vendor': _snmpVendor};
            setState(() { _snmpTargets.removeWhere((e) => e['host'] == device['host']); _snmpTargets.add(device); });
            Navigator.pop(ctx);
            await _readSnmp(device);
          }, child: const Text('حفظ واختبار')),
        ],
      ),
    ));
  }

  Future<void> _readSnmp(Map<String, String> device) async {
    try {
      final session = await Snmp.createSession(InternetAddress(device['host']!), community: device['community']!, port: 161, retries: 1, timeout: const Duration(seconds: 3), version: SnmpVersion.v2c);
      try {
        final response = await session.get(Oid.fromString(device['oid']!));
        final vars = response.pdu.varbinds;
        if (vars.isEmpty) throw Exception('No SNMP value');
        final raw = double.tryParse(vars.first.value.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
        if (raw == null) throw Exception('Non-numeric SNMP value');
        final signal = device['vendor'] == 'Mimosa' && device['oid'] == '1.3.6.1.4.1.43356.2.1.2.6.6' ? raw / 10 : raw;
        if (!mounted) return;
        setState(() {
          final i = _snmpTargets.indexWhere((e) => e['host'] == device['host']);
          if (i >= 0) _snmpTargets[i] = {..._snmpTargets[i], 'signal': signal.toStringAsFixed(1), 'snmpError': ''};
        });
      } finally { session.close(); }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _snmpTargets.indexWhere((e) => e['host'] == device['host']);
        if (i >= 0) _snmpTargets[i] = {..._snmpTargets[i], 'snmpError': 'تعذر قراءة SNMP: تحقق من التفعيل وOID وCommunity'};
      });
    }
  }

  Widget _snmpDeviceCard(Map<String, String> device) {
    final signal = double.tryParse(device['signal'] ?? '');
    final weak = signal != null && signal < -78;
    final color = weak ? AppColors.danger : AppColors.success;
    return Card(
      color: weak ? AppColors.danger.withOpacity(.1) : AppColors.bgCard,
      child: ListTile(
        leading: Icon(Icons.settings_input_antenna_rounded, color: color),
        title: Text(device['name'] ?? device['host']!),
        subtitle: Text((device['snmpError']?.isNotEmpty == true) ? device['snmpError']! : device['host']! + ' • ' + device['vendor']! + ' • OID ' + device['oid']!),
        trailing: signal == null ? IconButton(onPressed: () => _readSnmp(device), icon: const Icon(Icons.refresh)) : Text(signal.toStringAsFixed(1) + ' dBm', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        onTap: () => _readSnmp(device),
      ),
    );
  }


  String? _error;
  List<Map<String, String>> _radios = [];
  List<Map<String, String>> _neighbors = [];
  List<Map<String, String>> _leases = [];
  DateTime? _updated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final service = ref.read(mikrotikProvider);
    if (!service.isConnected) {
      setState(() => _error = 'اتصل بالراوتر أولاً لعرض بيانات الرادار.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        service.runCommand('/interface/wireless/registration-table'),
        service.runCommand('/interface/wifi/registration-table'),
        service.runCommand('/ip/neighbor'),
        service.runCommand('/ip/dhcp-server/lease'),
      ]);
      final merged = <Map<String, String>>[];
      final seen = <String>{};
      for (var i = 0; i < 2; i++) {
        for (final row in results[i]) {
          final key = '${row['mac-address'] ?? row['mac-addresses'] ?? ''}-${row['interface'] ?? ''}';
          if (seen.add(key) && key != '-') {
            merged.add({...row, '_source': i == 0 ? 'Wireless' : 'WiFi'});
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _radios = merged;
        _neighbors = results[2];
        _leases = results[3];
        _updated = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة بعض بيانات الرادار: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _signal(Map<String, String> row) {
    final value = row['signal-strength'] ?? row['signal'] ?? '';
    final match = RegExp(r'-?\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final weak = _radios.where((r) {
      final s = _signal(r);
      return s != null && s < -78;
    }).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('رادار صحون البث'),
        actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مراقبة الإشارة اللاسلكية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 8),
                Text('المسجلون لاسلكياً: ${_radios.length}   •   إشارة ضعيفة: $weak', style: const TextStyle(color: Colors.white)),
                if (_updated != null) Text('آخر تحديث: ${TimeOfDay.fromDateTime(_updated!).format(context)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: const TextStyle(color: AppColors.warning)))),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('الأجهزة المسجلة لاسلكياً', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_radios.isEmpty && !_loading) const _InfoTile(text: 'لا توجد بيانات تسجيل لاسلكي. قد لا يدعم الراوتر هذا المسار أو قد لا توجد أجهزة متصلة لاسلكياً به.'),
            ..._radios.map(_radioCard),
            const SizedBox(height: 18),
            Text('الجيران المكتشفون (${_neighbors.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_neighbors.isEmpty) const _InfoTile(text: 'لا توجد أجهزة ظاهرة في جدول الجيران حالياً.'),
            ..._neighbors.take(30).map((r) => _simpleCard(r, 'Neighbor')),
            const SizedBox(height: 18),
            Text('عناوين DHCP (${_leases.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_leases.isEmpty) const _InfoTile(text: 'لا توجد سجلات DHCP متاحة عبر هذا الاتصال.'),
            ..._leases.take(30).map((r) => _simpleCard(r, 'DHCP')),
            const SizedBox(height: 18),
            const _InfoTile(text: 'مهم: هذا الإصدار يقرأ بيانات MikroTik فقط. أجهزة Ubiquiti وMimosa تحتاج ربط SNMP أو واجهة إدارتها حتى تظهر قوة إشارتها. جدول الجيران وDHCP لا يكشف كل أجهزة الشبكة، والإشارة الأضعف من ‎-78 dBm إنذار أولي وليست وحدها دليلاً أن القطاع كله بطيء.'),
          ],
        ),
      ),
    );
  }

  Widget _radioCard(Map<String, String> row) {
    final signal = _signal(row);
    final isWeak = signal != null && signal < -78;
    final color = isWeak ? AppColors.danger : AppColors.success;
    return Card(
      color: isWeak ? AppColors.danger.withOpacity(.10) : AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isWeak ? AppColors.danger : AppColors.border, width: isWeak ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.settings_input_antenna_rounded, color: color, size: 27),
            const SizedBox(width: 10),
            Expanded(child: Text(row['radio-name'] ?? row['mac-address'] ?? row['mac-addresses'] ?? 'جهاز لاسلكي', style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(signal == null ? 'غير معروف' : '$signal dBm', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text('الواجهة: ${row['interface'] ?? '—'}   •   النوع: ${row['_source'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('MAC: ${row['mac-address'] ?? row['mac-addresses'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('TX/RX: ${row['tx-rate'] ?? '—'} / ${row['rx-rate'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (isWeak) const Padding(padding: EdgeInsets.only(top: 8), child: Text('⚠ إشارة ضعيفة — افحص المحاذاة والتشويش ومعدل الإرسال', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _simpleCard(Map<String, String> row, String type) {
    final name = row['identity'] ?? row['host-name'] ?? row['address'] ?? row['mac-address'] ?? 'جهاز';
    final details = [row['address'], row['mac-address'], row['interface'], row['platform']].where((v) => v != null && v!.isNotEmpty).join(' • ');
    return Card(child: ListTile(leading: Icon(type == 'DHCP' ? Icons.devices_rounded : Icons.hub_rounded, color: AppColors.secondary), title: Text(name), subtitle: Text(details.isEmpty ? type : details)));
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
