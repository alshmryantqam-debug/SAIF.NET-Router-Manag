import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';

class WanTtlScreen extends StatefulWidget {
  const WanTtlScreen({super.key});

  @override
  State<WanTtlScreen> createState() => _WanTtlScreenState();
}

class _WanTtlScreenState extends State<WanTtlScreen> {
  List<Map<String, dynamic>> _interfaces = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _mangle = [];
  bool _loading = false;
  final Set<String> _pending = {};
  String? _selectedWan;
  final _ttl = TextEditingController(text: '65');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _refresh(); });
  }

  @override
  void dispose() { _ttl.dispose(); super.dispose(); }

  bool _flag(dynamic value) => value?.toString().toLowerCase() == 'true' || value?.toString() == 'yes';
  Map<String, dynamic> _map(dynamic e) => Map<String, dynamic>.from(e as Map);

  Future<void> _refresh() async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) { _message('اتصل بالراوتر أولاً.', error: true); return; }
    setState(() => _loading = true);
    try {
      final data = await Future.wait<dynamic>([
        client.get('interface'),
        client.get('ip/route'),
        client.get('ip/firewall/mangle'),
      ]);
      if (!mounted) return;
      setState(() {
        _interfaces = (data[0] as List).whereType<Map>().map(_map).toList();
        _routes = (data[1] as List).whereType<Map>().map(_map).toList();
        _mangle = (data[2] as List).whereType<Map>().map(_map).toList();
        if (_selectedWan == null || !_interfaces.any((i) => i['name'] == _selectedWan)) {
          _selectedWan = _interfaces.isEmpty ? null : (_interfaces.first['name'] ?? '').toString();
        }
      });
    } on RosException catch (e) { _message('تعذر قراءة WAN: ${e.message}', error: true); }
    catch (e) { _message('تعذر قراءة إعدادات WAN: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? NovaColors.danger : NovaColors.surface2));
  }

  Future<void> _applyTtl() async {
    final client = context.read<ConnectionProvider>().client;
    final wan = _selectedWan;
    final ttl = int.tryParse(_ttl.text.trim());
    if (client == null || wan == null || ttl == null || ttl < 1 || ttl > 255) {
      _message('حدد واجهة موجودة وأدخل TTL بين 1 و255.', error: true); return;
    }
    final exists = _mangle.any((r) => (r['comment'] ?? '').toString() == 'NOVA-WAN-TTL:$wan');
    if (exists) { _message('توجد قاعدة NOVA-WAN-TTL لهذه الواجهة بالفعل؛ راجعها أدناه.', error: true); return; }
    final ok = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('تأكيد إضافة قاعدة TTL'),
      content: Text('سيُضاف rule في postrouting على الواجهة $wan بقيمة TTL=$ttl. راجع قواعد PCC والمزج الحالية قبل المتابعة.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إضافة القاعدة')),
      ],
    ));
    if (ok != true || !mounted) return;
    setState(() => _pending.add('ttl'));
    try {
      await client.put('ip/firewall/mangle', {
        'chain': 'postrouting', 'action': 'change-ttl', 'new-ttl': 'set:$ttl',
        'out-interface': wan, 'passthrough': 'yes', 'comment': 'NOVA-WAN-TTL:$wan',
      });
      await _refresh();
      _message('أُضيفت قاعدة TTL على $wan. لم يُختبر أثرها على مزود الخدمة.');
    } on RosException catch (e) { _message('رفض الراوتر القاعدة: ${e.message}', error: true); }
    catch (e) { _message('تعذر إضافة قاعدة TTL: $e', error: true); }
    finally { if (mounted) setState(() => _pending.remove('ttl')); }
  }

  Future<void> _removeTtl(Map<String, dynamic> rule) async {
    final client = context.read<ConnectionProvider>().client;
    final id = (rule['.id'] ?? '').toString();
    final comment = (rule['comment'] ?? '').toString();
    if (client == null || id.isEmpty || !comment.startsWith('NOVA-WAN-TTL:')) {
      _message('لا يمكن الحذف: القاعدة ليست موسومة من هذه الشاشة.', error: true); return;
    }
    final ok = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('حذف قاعدة TTL؟'),
      content: Text('سيُحذف فقط rule الذي يحمل التعليق $comment.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف القاعدة')),
      ],
    ));
    if (ok != true || !mounted) return;
    try {
      await client.delete('ip/firewall/mangle/${Uri.encodeComponent(id)}');
      await _refresh(); _message('تم حذف قاعدة TTL الموسومة.');
    } on RosException catch (e) { _message('تعذر حذف القاعدة: ${e.message}', error: true); }
    catch (e) { _message('تعذر حذف القاعدة: $e', error: true); }
  }

  Future<void> _editRoute(Map<String, dynamic> route, {bool prefer = false}) async {
    final client = context.read<ConnectionProvider>().client;
    final id = (route['.id'] ?? '').toString();
    if (client == null || id.isEmpty) { _message('لا يوجد معرّف للمسار.', error: true); return; }
    final current = int.tryParse((route['distance'] ?? '1').toString()) ?? 1;
    final controller = TextEditingController(text: (prefer ? 1 : (current + 1)).toString());
    var checkGateway = (route['check-gateway'] ?? 'none').toString();
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text(prefer ? 'تفضيل المسار' : 'تعديل أولوية المسار'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Gateway: ${route['gateway'] ?? '—'} · Dst: ${route['dst-address'] ?? '0.0.0.0/0'}'),
        TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Distance (الأقل أولوية أعلى)')),
        DropdownButtonFormField<String>(value: ['none','ping'].contains(checkGateway) ? checkGateway : 'none', decoration: const InputDecoration(labelText: 'فحص البوابة'), items: const [
          DropdownMenuItem(value: 'none', child: Text('بدون فحص')),
          DropdownMenuItem(value: 'ping', child: Text('Ping')),
        ], onChanged: (v) { if (v != null) setLocal(() => checkGateway = v); }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () { final d = int.tryParse(controller.text); if (d != null && d >= 1 && d <= 255) Navigator.pop(dialog, {'distance': d, 'check-gateway': checkGateway}); }, child: const Text('تطبيق')),
      ],
    )));
    controller.dispose();
    if (result == null || !mounted) return;
    final accepted = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('تأكيد تغيير المسار'),
      content: const Text('تغيير distance أو check-gateway قد يغيّر مسار الإنترنت فوراً أو يقطع الاتصال. هل تريد المتابعة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('تأكيد التغيير')),
      ],
    ));
    if (accepted != true || !mounted) return;
    setState(() => _pending.add(id));
    try {
      await client.patch('ip/route/${Uri.encodeComponent(id)}', {
        'distance': result['distance'].toString(), 'check-gateway': result['check-gateway'],
      });
      await _refresh(); _message('تم تحديث المسار حسب رد الراوتر.');
    } on RosException catch (e) { _message('رفض الراوتر تعديل المسار: ${e.message}', error: true); }
    catch (e) { _message('تعذر تعديل المسار: $e', error: true); }
    finally { if (mounted) setState(() => _pending.remove(id)); }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    final wanInterfaces = _interfaces.where((i) => (i['type'] ?? '').toString().toLowerCase().contains('ether') || (i['type'] ?? '').toString().toLowerCase().contains('sfp')).toList();
    final routes = _routes.where((r) => (r['dst-address'] ?? '').toString() == '0.0.0.0/0').toList();
    final tagged = _mangle.where((r) => (r['comment'] ?? '').toString().startsWith('NOVA-WAN-TTL:')).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات WAN وTTL'), actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')]),
      body: RefreshIndicator(onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الواجهات الفعلية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (!connected) const Text('اتصل بالراوتر أولاً.', style: TextStyle(color: NovaColors.danger)),
          if (_loading) const LinearProgressIndicator(),
          ..._interfaces.map((i) {
            final name = (i['name'] ?? '—').toString();
            final running = _flag(i['running']), disabled = _flag(i['disabled']);
            return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.cable, color: disabled ? NovaColors.danger : running ? NovaColors.success : NovaColors.warn),
              title: Text(name), subtitle: Text('${i['type'] ?? '—'} · MAC ${i['mac-address'] ?? '—'}'),
              trailing: Text(disabled ? 'معطّلة' : running ? 'تعمل' : 'لا يوجد رابط', style: TextStyle(color: disabled ? NovaColors.danger : running ? NovaColors.success : NovaColors.warn, fontSize: 12)));
          }),
        ])),
        const SizedBox(height: 12),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('قاعدة TTL موسومة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _selectedWan, decoration: const InputDecoration(labelText: 'واجهة WAN المراد ضبطها'),
            items: wanInterfaces.map((i) => DropdownMenuItem(value: (i['name'] ?? '').toString(), child: Text((i['name'] ?? '').toString()))).toList(),
            onChanged: (v) => setState(() => _selectedWan = v)),
          TextField(controller: _ttl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قيمة TTL')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: connected && !_loading && !_pending.contains('ttl') ? _applyTtl : null, icon: const Icon(Icons.add_rounded), label: const Text('إضافة قاعدة TTL')),
          ...tagged.map((r) => ListTile(contentPadding: EdgeInsets.zero, title: Text((r['comment'] ?? '').toString()), subtitle: Text('chain ${r['chain'] ?? '—'} · action ${r['action'] ?? '—'} · packets ${r['packets'] ?? '0'} · bytes ${r['bytes'] ?? '0'}'), trailing: IconButton(onPressed: () => _removeTtl(r), icon: const Icon(Icons.delete_outline, color: NovaColors.danger)))),
          const Text('لا يتم تغيير MAC أو تعديل قواعد PCC تلقائياً. قيمة TTL لا تضمن تجاوز سياسات مزود الخدمة.', style: TextStyle(color: NovaColors.muted, fontSize: 12)),
        ])),
        const SizedBox(height: 12),
        const Text('المسارات الافتراضية (0.0.0.0/0)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (routes.isEmpty) const GlassCard(child: Text('لا توجد مسارات افتراضية في القراءة الحالية.', style: TextStyle(color: NovaColors.muted))),
        ...routes.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gateway: ${r['gateway'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Distance ${r['distance'] ?? '—'} · check-gateway ${r['check-gateway'] ?? 'none'} · ${_flag(r['active']) ? 'نشط' : 'غير نشط'}', style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
              Text('Interface ${r['immediate-gw'] ?? '—'}', style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
            ])),
            IconButton(tooltip: 'تعديل الأولوية والفحص', onPressed: _loading ? null : () => _editRoute(r), icon: const Icon(Icons.tune_rounded)),
            IconButton(tooltip: 'تفضيل هذا المسار', onPressed: _loading ? null : () => _editRoute(r, prefer: true), icon: const Icon(Icons.vertical_align_top_rounded, color: NovaColors.primary)),
          ]),
        ])))),
        const Text('اختيار المسار الصحيح مسؤوليتك: راجع البوابة والواجهة قبل تعديل distance. لا يمكن اختبار تبديل الخطين من دون فحص اتصال فعلي.', style: TextStyle(color: NovaColors.warn, fontSize: 12, height: 1.5)),
      ])),
    );
  }
}
