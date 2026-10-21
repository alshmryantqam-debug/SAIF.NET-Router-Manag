import 'dart:async';

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
    // يمنع تشغيل عمليتين متزامنتين، حتى لو استُدعيت الدالة من مصدر آخر.
    if (_isBackingUp) return;

    final connected = ref.read(connectionProvider).isConnected;
    setState(() {
      _isBackingUp = true;
      _isSuccess = false;
      _isFailed = false;
      _processLogs.clear();
    });

    try {
      _addLog('تهيئة بروتوكول النسخ الاحتياطي...');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;

      if (!connected) {
        throw StateError('لا يوجد اتصال نشط بالراوتر. لم تبدأ عملية النسخ.');
      }

      _addLog('تم التحقق من وجود جلسة اتصال.');
      _addLog('النسخ الاحتياطي الفعلي غير موصول بخدمة التصدير بعد.');
      _addLog(
        'إيقاف آمن: لم يتم إنشاء ملف أو الادعاء بنجاح العملية.',
        isError: true,
      );
      if (!mounted) return;
      setState(() {
        _isBackingUp = false;
        _isFailed = true;
      });
    } catch (error) {
      if (!mounted) return;
      _addLog(error.toString(), isError: true);
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
                  'هذه الشاشة لا تنشئ نسخة فعلية بعد؛ يلزم ربط خدمة RouterOS لتصدير الإعدادات وحفظ الملف والتحقق منه.',
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
