import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class QueuesScreen extends ConsumerStatefulWidget {
  const QueuesScreen({super.key});

  @override
  ConsumerState<QueuesScreen> createState() => _QueuesScreenState();
}

class _QueuesScreenState extends ConsumerState<QueuesScreen> {
  List<Map<String, String>> _queues = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(mikrotikProvider).simpleQueues();
      if (!mounted) return;
      setState(() {
        _queues = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, String>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _queues;
    return _queues.where((row) =>
      (row['name'] ?? '').toLowerCase().contains(q) ||
      (row['target'] ?? '').toLowerCase().contains(q) ||
      (row['comment'] ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _edit(Map<String, String> queue) async {
    final id = queue['.id'] ?? queue['id'] ?? '';
    if (id.isEmpty) {
      _message('لم يرسل الراوتر معرّف Queue صالحاً.', error: true);
      return;
    }
    final ctrl = TextEditingController(text: queue['max-limit'] ?? '0/0');
    var backup = false;
    var rollback = false;
    var confirmed = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('تعديل حد السرعة'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(queue['name'] ?? 'Queue', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رفع/تنزيل', hintText: '5M/20M'),
            ),
            const SizedBox(height: 8),
            const Text('مثال: 5M/20M — لا تضع قيمة تقديرية إذا لم تكن متأكداً.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: backup,
              onChanged: (v) => setDialogState(() => backup = v ?? false),
              title: const Text('أنشأت نسخة احتياطية قابلة للاستعادة'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: rollback,
              onChanged: (v) => setDialogState(() => rollback = v ?? false),
              title: const Text('لدي خطة تراجع إذا انقطعت الخدمة'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (v) => setDialogState(() => confirmed = v ?? false),
              title: const Text('أوافق على تغيير هذا الحد على الراوتر الحقيقي'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: backup && rollback && confirmed ? () => Navigator.pop(ctx, true) : null,
            child: const Text('تطبيق التغيير'),
          ),
        ],
      )),
    );
    if (approved != true || !mounted) return;
    try {
      await ref.read(mikrotikProvider).updateSimpleQueueLimits(
        id,
        maxLimit: ctrl.text.trim(),
        explicitlyConfirmed: true,
        backupVerified: backup,
        rollbackPlanAvailable: rollback,
      );
      if (!mounted) return;
      _message('تم إرسال تحديث السرعة للراوتر.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _message(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _toggle(Map<String, String> queue) async {
    final id = queue['.id'] ?? queue['id'] ?? '';
    if (id.isEmpty) {
      _message('لم يرسل الراوتر معرّف Queue صالحاً.', error: true);
      return;
    }
    final currentlyDisabled = ['true', 'yes'].contains((queue['disabled'] ?? 'no').toLowerCase());
    final action = currentlyDisabled ? 'تفعيل' : 'تعطيل';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(action + ' Queue'),
        content: Text('هل تريد ' + action + ' "' + (queue['name'] ?? id) + '"؟ قد يتأثر اتصال المشترك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    var backup = false;
    var rollback = false;
    var finalConfirm = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('تأكيد أمان العملية'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: backup, onChanged: (v) => setDialogState(() => backup = v ?? false), title: const Text('النسخة الاحتياطية جاهزة'), controlAffinity: ListTileControlAffinity.leading),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: rollback, onChanged: (v) => setDialogState(() => rollback = v ?? false), title: const Text('خطة التراجع جاهزة'), controlAffinity: ListTileControlAffinity.leading),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: finalConfirm, onChanged: (v) => setDialogState(() => finalConfirm = v ?? false), title: Text('أؤكد ' + action + ' Queue على الراوتر'), controlAffinity: ListTileControlAffinity.leading),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: backup && rollback && finalConfirm ? () => Navigator.pop(ctx, true) : null, child: Text(action + ' الآن')),
        ],
      )),
    );
    if (approved != true || !mounted) return;
    try {
      await ref.read(mikrotikProvider).setSimpleQueueDisabled(
        id,
        !currentlyDisabled,
        explicitlyConfirmed: true,
        backupVerified: backup,
        rollbackPlanAvailable: rollback,
      );
      if (!mounted) return;
      _message('تم تحديث حالة Queue.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _message(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  String _limit(Map<String, String> row) {
    final value = row['max-limit'] ?? '—';
    return value == '0/0' ? 'غير محدود' : value;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة السرعات · Queues'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث باسم المشترك أو IP أو التعليق',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close_rounded)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(children: [
            _stat('إجمالي القوائم', _queues.length.toString(), Icons.speed_rounded),
            const SizedBox(width: 8),
            _stat('المعروضة', rows.length.toString(), Icons.filter_alt_rounded),
          ]),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.warning),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
              ])))
            : rows.isEmpty
              ? const Center(child: Text('لا توجد قوائم سرعة مطابقة.'))
              : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final disabled = ['true', 'yes'].contains((row['disabled'] ?? 'no').toLowerCase());
                    final name = row['name'] ?? 'Queue بدون اسم';
                    final target = row['target'] ?? '—';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: disabled ? AppColors.danger.withOpacity(.12) : AppColors.secondary.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.speed_rounded, color: disabled ? AppColors.danger : AppColors.secondary)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(target, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: disabled ? AppColors.danger.withOpacity(.12) : AppColors.success.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(disabled ? 'متوقف' : 'فعال', style: TextStyle(color: disabled ? AppColors.danger : AppColors.success, fontSize: 11, fontWeight: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 7),
                          const Text('حد السرعة', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const Spacer(),
                          Text(_limit(row), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        ]),
                        if ((row['comment'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(row['comment']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(onPressed: () => _edit(row), icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('تعديل السرعة'))),
                          const SizedBox(width: 8),
                          Expanded(child: FilledButton.tonalIcon(onPressed: () => _toggle(row), icon: Icon(disabled ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18), label: Text(disabled ? 'تفعيل' : 'إيقاف'))),
                        ]),
                      ]),
                    );
                  },
                )),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: AppColors.secondary, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ])),
    ]),
  ));
}
