import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;
  String _filter = '';
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadLogs(); });
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? NovaColors.danger : NovaColors.surface2));
  }

  Future<void> _loadLogs() async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) { setState(() => _error = 'اتصل بالراوتر أولاً.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await client.get('log');
      if (!mounted) return;
      setState(() => _logs = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList().reversed.toList());
    } on RosException catch (e) { if (mounted) setState(() => _error = e.message); }
    catch (e) { if (mounted) setState(() => _error = 'تعذر قراءة سجل الراوتر: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<bool> _confirm(String title, String message, {required String action}) async {
    return await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        FilledButton(style: action == 'reboot' ? FilledButton.styleFrom(backgroundColor: NovaColors.danger) : null,
          onPressed: () => Navigator.pop(dialog, true), child: const Text('تأكيد التنفيذ')),
      ],
    )) ?? false;
  }

  Future<void> _run(String action) async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) { _message('اتصل بالراوتر أولاً.', error: true); return; }
    String title, description;
    switch (action) {
      case 'reboot':
        title = 'إعادة تشغيل الراوتر؟';
        description = 'سيُعاد تشغيل الراوتر وقد تنقطع جميع اتصالات المشتركين والإدارة مؤقتاً.';
        break;
      case 'backup':
        title = 'إنشاء نسخة احتياطية؟';
        description = 'سيطلب التطبيق من RouterOS إنشاء ملف backup على الراوتر. هذا لا ينزّل الملف إلى الهاتف.';
        break;
      case 'check-update':
        title = 'فحص تحديثات الحزم؟';
        description = 'سيطلب التطبيق فحص التحديثات المتاحة دون تثبيتها تلقائياً.';
        break;
      default: return;
    }
    if (!await _confirm(title, description, action: action) || !mounted) return;
    setState(() => _loading = true);
    try {
      if (action == 'reboot') {
        await client.post('system/reboot');
        _message('أُرسل طلب إعادة التشغيل. قد ينقطع الاتصال قبل وصول تأكيد.');
      } else if (action == 'backup') {
        final name = 'nova-backup-${DateTime.now().toUtc().millisecondsSinceEpoch}';
        await client.post('system/backup/save', {'name': name});
        _message('أُرسل طلب النسخ الاحتياطي باسم $name. الملف محفوظ على الراوتر.');
      } else {
        await client.post('system/package/update/check-for-updates');
        final result = await client.get('system/package/update');
        _message('تم طلب فحص التحديثات. النتيجة: $result');
      }
    } on RosException catch (e) { _message('رفض الراوتر العملية: ${e.message}', error: true); }
    catch (e) { _message('تعذر تنفيذ العملية: $e', error: true); }
    finally { if (mounted) { setState(() => _loading = false); await _loadLogs(); } }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    final needle = _filter.trim().toLowerCase();
    final visible = _logs.where((entry) => needle.isEmpty || entry.values.join(' ').toLowerCase().contains(needle)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('غرفة العمليات'), actions: [
        IconButton(tooltip: 'تحديث السجل', onPressed: _loading ? null : _loadLogs, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(onRefresh: _loadLogs, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('أوامر مقيدة بقائمة بيضاء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text('أُزيل حقل تنفيذ الأوامر الحرة. الأزرار التالية تستدعي عمليات محددة فقط، وتطلب تأكيداً قبل التنفيذ.', style: TextStyle(color: NovaColors.muted, height: 1.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: connected && !_loading ? () => _run('backup') : null, icon: const Icon(Icons.backup_outlined), label: const Text('إنشاء Backup')),
            OutlinedButton.icon(onPressed: connected && !_loading ? () => _run('check-update') : null, icon: const Icon(Icons.system_update_alt), label: const Text('فحص تحديثات')),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: NovaColors.danger), onPressed: connected && !_loading ? () => _run('reboot') : null, icon: const Icon(Icons.restart_alt), label: const Text('إعادة تشغيل')),
          ]),
          if (!connected) const Padding(padding: EdgeInsets.only(top: 8), child: Text('لا يوجد اتصال بالراوتر.', style: TextStyle(color: NovaColors.danger))),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: NovaColors.danger))),
        ])),
        const SizedBox(height: 12),
        const Text('سجل RouterOS الحقيقي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(controller: _search, onChanged: (v) => setState(() => _filter = v), decoration: InputDecoration(labelText: 'فلترة السجل', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _filter.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() => _filter = ''); }, icon: const Icon(Icons.close_rounded)))),
        const SizedBox(height: 8),
        Text('المعروض ${visible.length} من ${_logs.length} سجل', style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
        if (visible.isEmpty && !_loading) const GlassCard(child: Text('لا توجد سجلات مطابقة أو لم تُقرأ السجلات بعد.', style: TextStyle(color: NovaColors.muted))),
        ...visible.map((entry) {
          final time = (entry['time'] ?? '—').toString();
          final topics = (entry['topics'] ?? '—').toString();
          final message = (entry['message'] ?? '—').toString();
          final danger = topics.contains('error') || topics.contains('critical');
          return Padding(padding: const EdgeInsets.only(bottom: 7), child: GlassCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(time, style: const TextStyle(color: NovaColors.muted, fontSize: 11))), Text(topics, style: TextStyle(color: danger ? NovaColors.danger : NovaColors.primary, fontSize: 11, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 5),
            SelectableText(message, style: const TextStyle(fontSize: 13, height: 1.45)),
          ])));
        }),
      ])),
    );
  }
}
