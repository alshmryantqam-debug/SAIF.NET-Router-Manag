import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';

class QueuesScreen extends StatefulWidget {
  const QueuesScreen({super.key});

  @override
  State<QueuesScreen> createState() => _QueuesScreenState();
}

class _QueuesScreenState extends State<QueuesScreen> {
  final TextEditingController _search = TextEditingController();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _flag(dynamic value) => value == true || value?.toString() == 'true';

  List<Map<String, dynamic>> _visible(List<dynamic> source) {
    final q = _search.text.trim().toLowerCase();
    return source.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) {
      if (q.isEmpty) return true;
      return (e['name'] ?? '').toString().toLowerCase().contains(q) ||
          (e['target'] ?? '').toString().toLowerCase().contains(q) ||
          (e['comment'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _refresh() async {
    await context.read<ConnectionProvider>().fetchQueues();
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

  String _formatBytes(dynamic value) {
    final bytes = double.tryParse(value?.toString() ?? '') ?? 0;
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${bytes.toStringAsFixed(0)} B';
  }

  Future<Map<String, String>?> _queueForm(Map<String, dynamic>? queue) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: (queue?['name'] ?? '').toString());
    final target = TextEditingController(text: (queue?['target'] ?? '').toString());
    final currentLimits = (queue?['max-limit'] ?? '0/0').toString().split('/');
    final upload = TextEditingController(text: currentLimits.isNotEmpty ? currentLimits[0] : '0');
    final download = TextEditingController(text: currentLimits.length > 1 ? currentLimits[1] : '0');
    final comment = TextEditingController(text: (queue?['comment'] ?? '').toString());

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 18),
                Text(queue == null ? 'إضافة حد سرعة جديد' : 'تعديل حد السرعة', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('سيتم حفظ التغيير مباشرة على MikroTik عند الضغط على حفظ.', style: TextStyle(color: NovaColors.muted, height: 1.5)),
                const SizedBox(height: 16),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم القاعدة', prefixIcon: Icon(Icons.label_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'اسم القاعدة مطلوب' : null),
                const SizedBox(height: 10),
                TextFormField(controller: target, decoration: const InputDecoration(labelText: 'الهدف (IP / شبكة / واجهة)', prefixIcon: Icon(Icons.lan_outlined), hintText: 'مثال: 192.168.88.10/32'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'أدخل عنوان IP أو الشبكة أو الواجهة المستهدفة' : null),
                const SizedBox(height: 14),
                const Text('الحد الأقصى للسرعة', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(controller: upload, decoration: const InputDecoration(labelText: 'حد الرفع', hintText: 'مثال: 5M'),
                    validator: (v) => _validLimit(v) ? null : 'مثال: 512k أو 5M')),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: download, decoration: const InputDecoration(labelText: 'حد التنزيل', hintText: 'مثال: 20M'),
                    validator: (v) => _validLimit(v) ? null : 'مثال: 512k أو 20M')),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: comment, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', prefixIcon: Icon(Icons.notes_rounded))),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.pop(sheet, {
                      'name': name.text.trim(),
                      'target': target.text.trim(),
                      'max-limit': '${upload.text.trim()}/${download.text.trim()}',
                      'comment': comment.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ على الراوتر'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('إلغاء')),
              ]),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    target.dispose();
    upload.dispose();
    download.dispose();
    comment.dispose();
    return result;
  }

  bool _validLimit(String? value) {
    final text = (value ?? '').trim();
    return RegExp(r'^\d+(\.\d+)?[kKmMgG]?$').hasMatch(text);
  }

  Future<void> _edit(Map<String, dynamic>? queue) async {
    final provider = context.read<ConnectionProvider>();
    final client = provider.client;
    if (!provider.isConnected || client == null) {
      _message('اتصل بالراوتر أولاً.', error: true);
      return;
    }
    final values = await _queueForm(queue);
    if (values == null || !mounted) return;
    final id = (queue?['.id'] ?? '').toString();
    if (queue != null && id.isEmpty) {
      _message('لم يرسل الراوتر معرّف قاعدة السرعة؛ لم يتم تعديلها.', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      if (queue == null) {
        await client.put('queue/simple', values);
      } else {
        await client.patch('queue/simple/${Uri.encodeComponent(id)}', values);
      }
      await provider.fetchQueues();
      _message(queue == null ? 'تمت إضافة قاعدة السرعة على الراوتر.' : 'تم حفظ تعديلات السرعة على الراوتر.');
    } on RosException catch (e) {
      _message('رفض الراوتر التغيير: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر حفظ قاعدة السرعة: $e', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> queue, bool enabled) async {
    final provider = context.read<ConnectionProvider>();
    final client = provider.client;
    final id = (queue['.id'] ?? '').toString();
    final name = (queue['name'] ?? 'قاعدة السرعة').toString();
    if (!provider.isConnected || client == null || id.isEmpty) {
      _message('تعذر تنفيذ العملية: تحقق من اتصال الراوتر ومعرّف القاعدة.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(enabled ? 'تفعيل قاعدة السرعة؟' : 'تعطيل قاعدة السرعة؟'),
        content: Text(enabled
          ? 'ستبدأ قاعدة $name بتطبيق حدود السرعة من جديد.'
          : 'سيتم إيقاف تطبيق حدود السرعة لهذه القاعدة، وقد يحصل الهدف على سرعة غير محددة بواسطتها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(enabled ? 'تفعيل' : 'تعطيل')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await client.patch('queue/simple/${Uri.encodeComponent(id)}', {'disabled': enabled ? 'false' : 'true'});
      await provider.fetchQueues();
      _message(enabled ? 'تم تفعيل قاعدة $name.' : 'تم تعطيل قاعدة $name.');
    } on RosException catch (e) {
      _message('رفض الراوتر العملية: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر تغيير حالة قاعدة السرعة: $e', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> queue) async {
    final provider = context.read<ConnectionProvider>();
    final client = provider.client;
    final id = (queue['.id'] ?? '').toString();
    final name = (queue['name'] ?? 'قاعدة السرعة').toString();
    if (!provider.isConnected || client == null || id.isEmpty) {
      _message('تعذر حذف القاعدة: تحقق من اتصال الراوتر ومعرّفها.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('حذف قاعدة السرعة نهائياً؟'),
        content: Text('سيتم حذف $name من الراوتر. هذا الإجراء لا يمكن التراجع عنه من داخل التطبيق.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: NovaColors.danger), onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await client.delete('queue/simple/${Uri.encodeComponent(id)}');
      await provider.fetchQueues();
      _message('تم حذف قاعدة $name.');
    } on RosException catch (e) {
      _message('رفض الراوتر الحذف: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر حذف قاعدة السرعة: $e', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _queueCard(Map<String, dynamic> queue) {
    final name = (queue['name'] ?? 'بدون اسم').toString();
    final target = (queue['target'] ?? '—').toString();
    final limits = (queue['max-limit'] ?? '0/0').toString().split('/');
    final upload = limits.isEmpty ? '—' : limits[0];
    final download = limits.length > 1 ? limits[1] : '—';
    final disabled = _flag(queue['disabled']);
    final id = (queue['.id'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: (disabled ? NovaColors.danger : NovaColors.primary).withOpacity(.15), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.speed_rounded, color: disabled ? NovaColors.danger : NovaColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(target, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
            ])),
            PopupMenuButton<String>(
              tooltip: 'إجراءات القاعدة',
              onSelected: (value) {
                if (value == 'edit') _edit(queue);
                if (value == 'delete') _delete(queue);
                if (value == 'toggle') _toggle(queue, disabled);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('تعديل السرعة'))),
                PopupMenuItem(value: 'toggle', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(disabled ? Icons.play_arrow_rounded : Icons.pause_rounded), title: Text(disabled ? 'تفعيل القاعدة' : 'تعطيل القاعدة'))),
                const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded), title: Text('حذف القاعدة'))),
              ],
            ),
          ]),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: _limitCell('حد الرفع', upload, Icons.north_rounded, const Color(0xFF8EA6FF))),
            const SizedBox(width: 10),
            Expanded(child: _limitCell('حد التنزيل', download, Icons.south_rounded, const Color(0xFF65C7B0))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(disabled ? 'القاعدة معطّلة' : 'حد السرعة مطبّق', style: TextStyle(fontSize: 12, color: disabled ? NovaColors.danger : NovaColors.success))),
            Switch(
              value: !disabled,
              onChanged: _working || id.isEmpty ? null : (enabled) => _toggle(queue, enabled),
            ),
          ]),
          if ((queue['comment'] ?? '').toString().trim().isNotEmpty)
            Align(alignment: AlignmentDirectional.centerStart, child: Text(queue['comment'].toString(), style: const TextStyle(color: NovaColors.muted, fontSize: 12))),
          const SizedBox(height: 2),
          Text('الحركة المسجلة · ${_formatBytes(queue['bytes'])}', style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _limitCell(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: NovaColors.surface2.withOpacity(.7), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final queues = _visible(provider.queues);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة السرعات والطوابير'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _working ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('قاعدة سرعة'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: NovaColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: NovaColors.gradient, borderRadius: BorderRadius.circular(25), border: Border.all(color: NovaColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('تحكّم مباشر في QoS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  StatusPill(provider.isConnected ? 'متصل' : 'غير متصل', provider.isConnected ? NovaColors.success : NovaColors.danger),
                ]),
                const SizedBox(height: 6),
                const Text('إضافة القواعد وتعديل حدود الرفع والتنزيل وتفعيلها أو حذفها مباشرة من MikroTik.', style: TextStyle(color: NovaColors.muted, height: 1.55)),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _summary('قواعد السرعة', '${provider.queues.length}', Icons.speed_rounded)),
                  Expanded(child: _summary('مفعّلة', '${provider.queues.whereType<Map>().where((q) => !_flag(q['disabled'])).length}', Icons.check_circle_outline_rounded)),
                  Expanded(child: _summary('معطّلة', '${provider.queues.whereType<Map>().where((q) => _flag(q['disabled'])).length}', Icons.pause_circle_outline_rounded)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1), child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث باسم القاعدة أو الهدف',
                prefixIcon: const Icon(Icons.search_rounded),
                border: InputBorder.none,
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _search.clear(); setState(() {}); }),
              ),
            )),
            if (_working) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
            const SizedBox(height: 12),
            if (!provider.isConnected)
              const GlassCard(child: EmptyState(icon: Icons.link_off_rounded, title: 'اتصل بالراوتر أولاً', message: 'بعد الاتصال ستتمكن من قراءة قواعد السرعة وإدارتها.'))
            else if (provider.isLoading && provider.queues.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (provider.errorMessage.isNotEmpty && provider.queues.isEmpty)
              GlassCard(child: EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر جلب قواعد السرعة', message: provider.errorMessage, actionLabel: 'إعادة المحاولة', onAction: _refresh))
            else if (queues.isEmpty)
              const GlassCard(child: EmptyState(icon: Icons.speed_outlined, title: 'لا توجد قواعد مطابقة', message: 'أضف قاعدة جديدة أو غيّر كلمات البحث.'))
            else
              ...queues.map(_queueCard),
            const SizedBox(height: 8),
            const Text('ملاحظة: حدود max-limit تُدخل بصيغة الرفع/التنزيل، مثل 5M/20M. راجع الهدف قبل الحفظ حتى لا تُطبّق السرعة على مشترك خاطئ.', style: TextStyle(color: NovaColors.warn, fontSize: 12, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 20, color: NovaColors.primary),
    const SizedBox(height: 8),
    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
  ]);
}
