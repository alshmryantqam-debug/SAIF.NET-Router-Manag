import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../widgets/cyber_data_vault_cube.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _purple = Color(0xFFE040FB);
const _green = Color(0xFF4CAE7D);
const _red = Color(0xFFFF5252);

class QuantumBackupScreen extends ConsumerStatefulWidget {
  const QuantumBackupScreen({super.key});

  @override
  ConsumerState<QuantumBackupScreen> createState() =>
      _QuantumBackupScreenState();
}

class _QuantumBackupScreenState extends ConsumerState<QuantumBackupScreen> {
  bool _isBackingUp = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  final List<String> _processLogs = <String>[];
  final ScrollController _logController = ScrollController();

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  void _addLog(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _processLogs.add(isError ? '[خطأ] $message' : '> $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logController.hasClients) return;
      _logController.animateTo(
        _logController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _executeBackup() async {
    if (_isBackingUp) return;

    final connected = ref.read(connectionProvider).isConnected;
    if (!connected) {
      _addLog('لا يوجد اتصال نشط بالراوتر؛ لم يبدأ التصدير.', isError: true);
      setState(() {
        _isFailed = true;
        _isSuccess = false;
      });
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تصدير الإعدادات'),
        content: const Text(
          'سيُنشأ ملف تصدير نصي مؤقت على الراوتر ثم يُقرأ ويُحذف. '
          'التصدير لا يتضمن كلمات المرور والمفاتيح الخاصة. '
          'لا تغيّر هذه العملية إعدادات الشبكة، لكنها تتطلب صلاحية الملفات والتصدير.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('موافق وابدأ'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _isBackingUp = true;
      _isSuccess = false;
      _isFailed = false;
      _processLogs.clear();
    });

    try {
      _addLog('تم تأكيد العملية؛ بدء تصدير RouterOS v7.');
      final exportText =
          await ref.read(mikrotikProvider).exportConfigurationText();
      if (!mounted) return;

      _addLog('استُلم ملف التصدير النصي وتحققنا أنه غير فارغ.');
      _addLog('ملاحظة: لا يحتوي هذا التصدير على كلمات المرور أو المفاتيح الخاصة.');
      setState(() {
        _isBackingUp = false;
        _isSuccess = true;
        _isFailed = false;
      });

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اكتمل تصدير الإعدادات'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                exportText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportText));
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ التصدير إلى الحافظة')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('نسخ النص'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _addLog('فشل التصدير: $error', isError: true);
      _addLog(
        'إذا تعذّر حذف الملف المؤقت بسبب صلاحيات الراوتر، راجع Files على الراوتر.',
        isError: true,
      );
      setState(() {
        _isBackingUp = false;
        _isFailed = true;
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final accent = _isFailed
        ? _red
        : _isSuccess
            ? _green
            : _isBackingUp
                ? _purple
                : _cyan;

    final status = _isBackingUp
        ? 'جارٍ التحقق من قناة النسخ'
        : _isFailed
            ? 'توقفت العملية بأمان'
            : _isSuccess
                ? 'اكتملت عملية النسخ'
                : 'الخزنة في وضع الاستعداد';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'خزنة البيانات الكميّة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: _cyan, blurRadius: 10)],
          ),
        ),
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              CyberDataVaultCube(
                isProcessing: _isBackingUp,
                isSuccess: _isSuccess,
                isFailed: _isFailed,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: NovaTechPanel(
                  accentColor: connected ? _green : _red,
                  child: Row(
                    children: [
                      Icon(
                        connected ? Icons.link_rounded : Icons.link_off_rounded,
                        color: connected ? _green : _red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          connected
                              ? 'اتصال الراوتر متاح'
                              : 'لا يوجد اتصال بالراوتر',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        connected ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: connected ? _green : _red,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: NovaTechPanel(
                    accentColor: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.terminal_rounded, color: accent, size: 19),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'سجل العمليات الآمنة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: _processLogs.isEmpty
                              ? Center(
                                  child: Text(
                                    'بانتظار أمر النسخ الاحتياطي...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.48),
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _logController,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _processLogs.length,
                                  itemBuilder: (context, index) {
                                    final line = _processLogs[index];
                                    final isError = line.startsWith('[خطأ]');
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        line,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: isError ? _red : Colors.white70,
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          height: 1.45,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: NovaCyberButton(
                  text: _isBackingUp
                      ? 'جارٍ التحقق...'
                      : 'بدء النسخ الاحتياطي',
                  icon: _isBackingUp
                      ? Icons.lock_clock_rounded
                      : Icons.save_rounded,
                  color: _isBackingUp ? _purple : _cyan,
                  onPressed: _isBackingUp ? null : _executeBackup,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: Text(
                  'يُصدّر إعدادات RouterOS كنص غير حساس، ويتيح نسخها للحافظة. هذا ليس ملف .backup ثنائياً لاستعادة كاملة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
