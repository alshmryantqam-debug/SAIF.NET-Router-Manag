import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme.dart';

class RoutersListScreen extends StatefulWidget {
  const RoutersListScreen({super.key});

  @override
  State<RoutersListScreen> createState() => _RoutersListScreenState();
}

class _RoutersListScreenState extends State<RoutersListScreen> {
  final StorageService _storage = StorageService();
  String _status = 'جارٍ تحميل بيانات الراوتر المحفوظ...';
  String? _name;
  String? _host;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final router = await _storage.load();
      if (!mounted) return;
      setState(() {
        _name = router?.name;
        _host = router?.host;
        _status = router == null ? 'لا يوجد راوتر محفوظ على هذا الجهاز' : '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'تعذّر قراءة بيانات الراوتر المحفوظة';
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف بيانات الراوتر؟'),
        content: const Text('سيتم حذف بيانات الاتصال المحفوظة من هذا الجهاز فقط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف البيانات'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.clear();
    if (!mounted) return;
    setState(() {
      _name = null;
      _host = null;
      _status = 'تم حذف بيانات الاتصال المحفوظة';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRouter = _name != null && _host != null;
    return Scaffold(
      appBar: AppBar(title: const Text('أجهزة الراوتر')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.router_rounded, color: AppTheme.primary, size: 30),
                SizedBox(height: 12),
                Text('اتصالات محفوظة', style: TextStyle(color: AppTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('إدارة بيانات الاتصال المخزنة محلياً على هذا الجهاز.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (hasRouter)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.router_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(_host!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف بيانات الاتصال',
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppTheme.success, size: 17),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('بيانات الاعتماد محفوظة عبر التخزين الآمن للنظام',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.router_outlined, size: 40, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
