import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';

class HotspotOperationsScreen extends StatefulWidget {
  const HotspotOperationsScreen({super.key});

  @override
  State<HotspotOperationsScreen> createState() => _HotspotOperationsScreenState();
}

class _HotspotOperationsScreenState extends State<HotspotOperationsScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = false;
  bool _working = false;
  String? _error;
  final _count = TextEditingController(text: '10');
  final _prefix = TextEditingController(text: 'SAIF-');
  final _length = TextEditingController(text: '6');
  final _duration = TextEditingController(text: '1d');
  String? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _refresh(); });
  }

  @override
  void dispose() {
    _count.dispose();
    _prefix.dispose();
    _length.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? NovaColors.danger : NovaColors.surface2));
  }

  Map<String, dynamic> _map(dynamic value) => Map<String, dynamic>.from(value as Map);

  Future<void> _refresh() async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) {
      setState(() => _error = 'اتصل بالراوتر أولاً.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        client.get('ip/hotspot/user'),
        client.get('ip/hotspot/active'),
        client.get('ip/hotspot/user/profile'),
      ]);
      if (!mounted) return;
      setState(() {
        _users = (results[0] as List).whereType<Map>().map(_map).toList();
        _active = (results[1] as List).whereType<Map>().map(_map).toList();
        _profiles = (results[2] as List).whereType<Map>().map(_map).toList();
        if (_profile == null || !_profiles.any((p) => p['name'] == _profile)) {
          _profile = _profiles.isEmpty ? null : (_profiles.first['name'] ?? '').toString();
        }
      });
    } on RosException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة بيانات الهوتسبوت: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect(Map<String, dynamic> session) async {
    final client = context.read<ConnectionProvider>().client;
    final id = (session['.id'] ?? '').toString();
    final user = (session['user'] ?? 'مشترك').toString();
    if (client == null || id.isEmpty) {
      _message('تعذر الفصل: لا يوجد اتصال أو معرّف جلسة.', error: true);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('فصل جلسة الهوتسبوت'),
        content: Text('سيتم فصل $user فوراً من الراوتر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('فصل الآن')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await client.delete('ip/hotspot/active/${Uri.encodeComponent(id)}');
      await _refresh();
      _message('تم إرسال أمر الفصل وتحديث الجلسات.');
    } on RosException catch (e) {
      _message('رفض الراوتر فصل الجلسة: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر فصل الجلسة: $e', error: true);
    }
  }

  Future<void> _createProfile() async {
    final name = TextEditingController();
    final rate = TextEditingController(text: '5M/20M');
    final shared = TextEditingController(text: '1');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('إنشاء بروفايل هوتسبوت'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم البروفايل')),
          TextField(controller: rate, decoration: const InputDecoration(labelText: 'حد السرعة upload/download', helperText: 'مثال: 5M/20M')),
          TextField(controller: shared, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الجلسات المتزامنة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إنشاء')),
        ],
      ),
    );
    final n = name.text.trim(), r = rate.text.trim(), sh = int.tryParse(shared.text.trim());
    name.dispose(); rate.dispose(); shared.dispose();
    if (accepted != true || !mounted) return;
    if (n.isEmpty || r.isEmpty || sh == null || sh < 1) {
      _message('تحقق من الاسم والسرعة وعدد الجلسات.', error: true);
      return;
    }
    final client = context.read<ConnectionProvider>().client;
    if (client == null) { _message('اتصل بالراوتر أولاً.', error: true); return; }
    try {
      await client.put('ip/hotspot/user/profile', {'name': n, 'rate-limit': r, 'shared-users': sh.toString()});
      await _refresh();
      _message('تم إنشاء البروفايل على الراوتر.');
    } on RosException catch (e) {
      _message('رفض الراوتر إنشاء البروفايل: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر إنشاء البروفايل: $e', error: true);
    }
  }

  Future<void> _generate() async {
    final client = context.read<ConnectionProvider>().client;
    final count = int.tryParse(_count.text.trim());
    final length = int.tryParse(_length.text.trim());
    final prefix = _prefix.text.trim();
    final duration = _duration.text.trim();
    final profile = _profile;
    if (client == null || count == null || count < 1 || count > 500 ||
        length == null || length < 4 || length > 16 || duration.isEmpty || profile == null || profile.isEmpty) {
      _message('اتصل بالراوتر وحدد العدد (1–500) وطول الرمز (4–16) والمدة والبروفايل.', error: true);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('تأكيد إنشاء البطاقات'),
        content: Text('سيُنشأ $count حساباً حقيقياً على الراوتر. البادئة: $prefix، المدة: $duration، البروفايل: $profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إنشاء الحسابات')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() { _working = true; _error = null; });
    var created = 0;
    try {
      const digits = '0123456789';
      final random = Random.secure();
      final existing = _users.map((u) => (u['name'] ?? '').toString()).toSet();
      for (var i = 0; i < count; i++) {
        String code;
        var attempts = 0;
        do {
          code = '$prefix${List.generate(length, (_) => digits[random.nextInt(digits.length)]).join()}';
          attempts++;
          if (attempts > 100) throw StateError('تعذر توليد رمز فريد؛ غيّر البادئة أو طول الرمز.');
        } while (existing.contains(code));
        await client.put('ip/hotspot/user', {
          'name': code, 'password': code, 'profile': profile,
          'server': 'all', 'limit-uptime': duration, 'comment': 'NOVA-GENERATED',
        });
        existing.add(code);
        created++;
      }
      await _refresh();
      _message('أنشأ الراوتر $created من $count بطاقة.');
    } on RosException catch (e) {
      _message('تم إنشاء $created بطاقة قبل توقف العملية. رفض الراوتر الطلب: ${e.message}', error: true);
    } catch (e) {
      _message('تم إنشاء $created بطاقة قبل توقف العملية: $e', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_users.isEmpty) { _message('لا توجد حسابات مقروءة لتصديرها.', error: true); return; }
    String cell(dynamic value) {
      final s = (value ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }
    final lines = <String>[
      ['name', 'profile', 'server', 'disabled', 'limit-uptime', 'comment'].map(cell).join(','),
      ..._users.map((u) => ['name', 'profile', 'server', 'disabled', 'limit-uptime', 'comment'].map((k) => cell(u[k])).join(',')),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    _message('تم نسخ CSV الحقيقي من ${_users.length} حساباً إلى الحافظة. الصقه في ملف .csv.');
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الهوتسبوت المتقدمة'), actions: [
        IconButton(tooltip: 'تحديث من الراوتر', onPressed: _loading || _working ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'نسخ CSV', onPressed: _loading || _users.isEmpty ? null : _exportCsv, icon: const Icon(Icons.file_download_outlined)),
      ]),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('حالة حقيقية من RouterOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('المستخدمون: ${_users.length} · الجلسات النشطة: ${_active.length} · البروفايلات: ${_profiles.length}', style: const TextStyle(color: NovaColors.muted)),
            if (!connected) const Padding(padding: EdgeInsets.only(top: 8), child: Text('اتصل بالراوتر لقراءة البيانات وتنفيذ العمليات.', style: TextStyle(color: NovaColors.danger))),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: NovaColors.danger))),
          ])),
          const SizedBox(height: 12),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('توليد بطاقات دفعة واحدة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: _count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد البطاقات (1–500)')),
            TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'البادئة')),
            TextField(controller: _length, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'طول الجزء الرقمي (4–16)')),
            TextField(controller: _duration, decoration: const InputDecoration(labelText: 'مدة الاستخدام', helperText: 'صيغة RouterOS مثل 1d أو 12h')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _profile,
              decoration: const InputDecoration(labelText: 'البروفايل (من الراوتر)'),
              items: _profiles.map((p) => DropdownMenuItem<String>(value: (p['name'] ?? '').toString(), child: Text((p['name'] ?? '—').toString()))).toList(),
              onChanged: _working ? null : (v) => setState(() => _profile = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: connected && !_working ? _createProfile : null, icon: const Icon(Icons.add_circle_outline), label: const Text('إنشاء بروفايل سرعة')),
            const SizedBox(height: 6),
            FilledButton.icon(onPressed: connected && !_working && !_loading && _profiles.isNotEmpty ? _generate : null, icon: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text('إنشاء البطاقات على الراوتر')),
            const SizedBox(height: 6),
            const Text('السرعة تأتي من البروفايل المحدد على الراوتر؛ لا تُعرض سرعة مخصصة إلا إذا كانت مضبوطة فعلياً في البروفايل.', style: TextStyle(color: NovaColors.muted, fontSize: 12)),
          ])),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Text('الجلسات النشطة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Text('${_active.length}', style: const TextStyle(color: NovaColors.primary, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          if (_active.isEmpty) const GlassCard(child: Text('لا توجد جلسات نشطة حسب القراءة الحالية.', style: TextStyle(color: NovaColors.muted))),
          ..._active.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(child: Row(children: [
            const Icon(Icons.wifi, color: NovaColors.success),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((s['user'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('IP: ${s['address'] ?? '—'} · MAC: ${s['mac-address'] ?? '—'}', style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
              Text('المدة: ${s['uptime'] ?? '—'} · ID: ${s['.id'] ?? '—'}', style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
            ])),
            IconButton(tooltip: 'فصل الجلسة', onPressed: _working ? null : () => _disconnect(s), icon: const Icon(Icons.link_off, color: NovaColors.danger)),
          ])))),
        ]),
      ),
    );
  }
}
