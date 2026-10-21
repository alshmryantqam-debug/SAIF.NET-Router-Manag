import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';

/// Operates only on rules explicitly tagged by this application.
/// It never rewrites or deletes unrelated firewall rules.
class CyberShieldScreen extends StatefulWidget {
  const CyberShieldScreen({super.key});

  @override
  State<CyberShieldScreen> createState() => _CyberShieldScreenState();
}

class _CyberShieldScreenState extends State<CyberShieldScreen> {
  static const _groups = <String, String>{
    'PORTSCAN': 'حظر مسح المنافذ',
    'BRUTEFORCE': 'حماية SSH / Winbox / API من التخمين',
    'CONNECTION_LIMIT': 'حد الاتصالات لكل عنوان IP',
    'DNS': 'حماية DNS المفتوح',
    'SYN_FLOOD': 'حماية SYN flood',
  };

  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = false;
  String? _error;
  final Set<String> _pending = {};

  bool _enabled(dynamic value) {
    final v = value?.toString().toLowerCase();
    return v != 'true' && v != 'yes';
  }

  String? _group(Map<String, dynamic> rule) {
    final comment = (rule['comment'] ?? '').toString();
    for (final key in _groups.keys) {
      if (comment.startsWith('NOVA-CYBER:$key')) return key;
    }
    return null;
  }

  Future<void> _load() async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) {
      setState(() { _error = 'اتصل بالراوتر أولاً.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        client.get('ip/firewall/filter'),
        client.get('ip/firewall/address-list'),
      ]);
      if (!mounted) return;
      setState(() {
        _rules = (results[0] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => _group(e) != null)
            .toList();
        _blocked = (results[1] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => (e['list'] ?? '').toString() == 'nova-cyber-blocked')
            .toList();
      });
    } on RosException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة قواعد الحماية: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _forGroup(String key) =>
      _rules.where((rule) => _group(rule) == key).toList();

  Future<void> _toggleGroup(String key, bool enable) async {
    final client = context.read<ConnectionProvider>().client;
    final rules = _forGroup(key);
    if (client == null) {
      _message('اتصل بالراوتر أولاً.', error: true);
      return;
    }
    if (rules.isEmpty) {
      _message('لا توجد قواعد موسومة للمجموعة «${_groups[key]}». لم يُنشئ التطبيق قواعد تلقائياً.', error: true);
      return;
    }
    setState(() => _pending.add(key));
    try {
      for (final rule in rules) {
        final id = (rule['.id'] ?? '').toString();
        if (id.isEmpty) throw StateError('أعاد الراوتر قاعدة بلا معرّف.');
        await client.patch('ip/firewall/filter/${Uri.encodeComponent(id)}', {
          'disabled': enable ? 'false' : 'true',
        });
      }
      await _load();
      _message('تم ${enable ? 'تفعيل' : 'تعطيل'} «${_groups[key]}» على الراوتر.');
    } on RosException catch (e) {
      _message('رفض الراوتر العملية: ${e.message}', error: true);
      await _load();
    } catch (e) {
      _message('لم تكتمل العملية: $e', error: true);
      await _load();
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  Future<void> _unban(Map<String, dynamic> item) async {
    final client = context.read<ConnectionProvider>().client;
    final id = (item['.id'] ?? '').toString();
    final address = (item['address'] ?? 'عنوان غير معروف').toString();
    if (client == null || id.isEmpty) {
      _message('لا يمكن رفع الحظر: اتصال الراوتر أو معرّف العنوان غير متاح.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('رفع الحظر؟'),
        content: Text('سيُحذف $address من قائمة nova-cyber-blocked على الراوتر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('رفع الحظر')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await client.delete('ip/firewall/address-list/${Uri.encodeComponent(id)}');
      await _load();
      _message('تم رفع الحظر عن $address.');
    } on RosException catch (e) {
      _message('تعذر رفع الحظر: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر رفع الحظر: $e', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? NovaColors.danger : NovaColors.surface2,
      ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('درع الحماية السيبراني'),
        actions: [IconButton(tooltip: 'تحديث من الراوتر', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إدارة القواعد الموجودة فعلياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('تعرض هذه الشاشة فقط قواعد الجدار الناري التي تحمل تعليق NOVA-CYBER. لا تنشئ قواعد تلقائياً ولا تعدّل قواعد أخرى.', style: TextStyle(color: NovaColors.muted, height: 1.5)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _metric('قواعد موسومة', '${_rules.length}')),
                Expanded(child: _metric('عناوين محظورة', '${_blocked.length}')),
              ]),
            ])),
            const SizedBox(height: 12),
            if (!connected) const GlassCard(child: EmptyState(icon: Icons.link_off_rounded, title: 'اتصل بالراوتر أولاً', message: 'لا تُعرض أي حالة افتراضية؛ يلزم اتصال حقيقي.')),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) GlassCard(child: Text(_error!, style: const TextStyle(color: NovaColors.danger))),
            ..._groups.entries.map((entry) {
              final rules = _forGroup(entry.key);
              final enabled = rules.isNotEmpty && rules.any((r) => _enabled(r['disabled']));
              final packets = rules.fold<int>(0, (sum, r) => sum + (int.tryParse('${r['packets'] ?? ''}') ?? 0));
              final bytes = rules.fold<int>(0, (sum, r) => sum + (int.tryParse('${r['bytes'] ?? ''}') ?? 0));
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(child: Column(children: [
                  Row(children: [
                    Expanded(child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (_pending.contains(entry.key)) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else Switch(value: enabled, onChanged: connected && !_loading && rules.isNotEmpty ? (v) => _toggleGroup(entry.key, v) : null),
                  ]),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text(
                    rules.isEmpty ? 'غير مهيّأ: لا توجد قواعد بهذا التعليق' : '${rules.length} قاعدة · ${rules.where((r) => _enabled(r['disabled'])).length} مفعّلة',
                    style: const TextStyle(color: NovaColors.muted, fontSize: 12),
                  )),
                  if (rules.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Expanded(child: Text('Packets: $packets', style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('Bytes: $bytes', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
                ])),
              );
            }),
            const SizedBox(height: 8),
            const Text('قائمة الحظر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (_blocked.isEmpty)
              const GlassCard(child: Text('لا توجد عناوين في القائمة nova-cyber-blocked حسب القراءة الحالية.', style: TextStyle(color: NovaColors.muted)))
            else
              ..._blocked.map((item) {
                final address = (item['address'] ?? '—').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(child: Row(children: [
                    const Icon(Icons.gpp_bad_outlined, color: NovaColors.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(address, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text((item['comment'] ?? item['list'] ?? '').toString(), style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
                    ])),
                    TextButton(onPressed: _loading ? null : () => _unban(item), child: const Text('رفع الحظر')),
                  ])),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
  ]);
}
