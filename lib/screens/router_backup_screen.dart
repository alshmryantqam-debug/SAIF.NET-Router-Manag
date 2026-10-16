import 'package:flutter/material.dart';

import '../services/router_backup_vault.dart';
import '../theme.dart';

class RouterBackupScreen extends StatefulWidget {
  const RouterBackupScreen({super.key});

  @override
  State<RouterBackupScreen> createState() => _RouterBackupScreenState();
}

class _RouterBackupScreenState extends State<RouterBackupScreen> {
  final _vault = RouterBackupVault();
  final _label = TextEditingController();
  final _configuration = TextEditingController();
  List<RouterBackupRecord> _records = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _label.dispose();
    _configuration.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _vault.listBackups();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر قراءة خزنة النسخ المشفّرة';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _configuration.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم النسخة ومحتوى تصدير RouterOS أولاً')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _vault.createBackup(
        label: _label.text,
        configurationText: _configuration.text,
      );
      _configuration.clear();
      _label.clear();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تشفير النسخة وحفظها محلياً')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حفظ النسخة: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _inspect(RouterBackupRecord record) async {
    if (!record.readable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر التحقق من النسخة أو مفتاح التشفير غير متاح')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عرض إعدادات حساسة؟'),
        content: const Text('قد تحتوي النسخة على عناوين الشبكة ومعلومات حساسة. اعرضها فقط في مكان خاص. لن تُنفّذ أي أوامر على الراوتر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('عرض للمراجعة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final configuration = await _vault.readBackupConfiguration(record.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(record.label),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(configuration, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4)),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل فك التشفير أو فشل التحقق من سلامة النسخة')),
      );
    }
  }

  Future<void> _delete(RouterBackupRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النسخة؟'),
        content: Text('سيتم حذف النسخة المحلية «${record.label}» نهائياً من هذا الجهاز.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _vault.deleteBackup(record.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خزنة النسخ المشفّرة'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.enhanced_encryption_rounded, color: AppTheme.primary, size: 28),
                SizedBox(height: 10),
                Text('نسخ محلية بتشفير AES-256-GCM', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('الصق تصدير RouterOS الذي حصلت عليه بنفسك. يُشفّر المحتوى قبل حفظه على الجهاز.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إنشاء نسخة مشفّرة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: _label,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'اسم النسخة', hintText: 'مثال: CCR2116 قبل التعديل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _configuration,
                  minLines: 5,
                  maxLines: 10,
                  style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'محتوى تصدير RouterOS',
                    hintText: 'الصق النص هنا — تجنّب مشاركة النص الأصلي مع أي جهة',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_rounded),
                    label: Text(_saving ? 'جارٍ التشفير...' : 'تشفير وحفظ على هذا الجهاز'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('مهم: مفتاح التشفير محفوظ في التخزين الآمن لهذا الجهاز. حذف بيانات التطبيق أو فقدان المفتاح قد يمنع فتح النسخ؛ لا تعتبرها نسخة خارجية للتعافي بعد فقدان الهاتف.', style: TextStyle(color: AppTheme.warning, fontSize: 11, height: 1.6)),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('النسخ المحفوظة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900))),
            Text('${_records.length}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.danger))
          else if (_records.isEmpty) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
            child: const Text('لا توجد نسخ بعد. إنشاء نسخة لا يغيّر إعدادات الراوتر.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          )
          else ..._records.map((record) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: record.readable ? AppTheme.border : AppTheme.danger.withOpacity(0.5))),
            child: ListTile(
              leading: Icon(record.readable ? Icons.verified_user_rounded : Icons.warning_amber_rounded, color: record.readable ? AppTheme.success : AppTheme.danger),
              title: Text(record.label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text('${record.createdAt.year == 1970 ? 'تاريخ غير متاح' : record.createdAt.toLocal().toString().substring(0, 16)} · ${(record.fileSize / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'inspect') _inspect(record);
                  if (value == 'delete') _delete(record);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'inspect', child: Text('فك التشفير للمراجعة')),
                  PopupMenuItem(value: 'delete', child: Text('حذف النسخة')),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
