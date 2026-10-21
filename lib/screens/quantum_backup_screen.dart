import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../widgets/cyber_data_vault_cube.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _red = Color(0xFFFF5252);
const _green = Color(0xFF4CAE7D);
const _muted = Color(0xFF91A0B8);

class QuantumBackupScreen extends ConsumerStatefulWidget {
  const QuantumBackupScreen({super.key});

  @override
  ConsumerState<QuantumBackupScreen> createState() =>
      _QuantumBackupScreenState();
}

class _QuantumBackupScreenState extends ConsumerState<QuantumBackupScreen> {
  bool _isBackingUp = false;
  bool _finished = false;
  final List<String> _processLogs = <String>[];
  final ScrollController _logController = ScrollController();

  static const _steps = <String>[
    '> تهيئة قناة العمليات الآمنة...',
    '> التحقق من جلسة الاتصال بالراوتر...',
    '> قراءة هوية الجهاز وإصدار RouterOS...',
    '> جرد الواجهات ومؤشرات النظام المتاحة...',
    '> تجهيز سجل محلي توضيحي لمراحل النسخ...',
    '> محاكاة مرحلة التشفير وعزل البيانات...',
    '> انتهت المحاكاة؛ لم يُنشأ ملف Backup فعلي.',
  ];

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _startBackupProcess() async {
    if (_isBackingUp) return;
    final connected = ref.read(connectionProvider).isConnected;
    setState(() {
      _isBackingUp = true;
      _finished = false;
      _processLogs
        ..clear()
        ..add('> بدء بروتوكول الخزنة...');
        if (!connected) {
          _processLogs.add('! لا يوجد اتصال نشط بالراوتر.');
        }
    });

    for (final step in _steps) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _processLogs.add(step));
      _scrollLogsToEnd();
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _isBackingUp = false;
      _finished = true;
    });
    _scrollLogsToEnd();
  }

  void _scrollLogsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logController.hasClients) return;
      _logController.animateTo(
        _logController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final accent = _isBackingUp ? _red : _cyan;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'خزنة البيانات الكميّة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: _cyan, blurRadius: 12)],
          ),
        ),
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              NovaTechPanel(
                accentColor: connected ? _green : _red,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      connected ? Icons.verified_user_rounded : Icons.link_off_rounded,
                      color: connected ? _green : _red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected
                            ? 'قناة الراوتر متصلة'
                            : 'لا يوجد اتصال نشط بالراوتر',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      connected ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: connected ? _green : _red,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'واجهة عرض تجريبية: لا تنفّذ هذه النسخة تصدير RouterOS أو تشفير ملف حقيقي.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 8),
              CyberDataVaultCube(isProcessing: _isBackingUp),
              const SizedBox(height: 4),
              Text(
                _isBackingUp
                    ? 'النظام في وضع العزل والمحاكاة'
                    : _finished
                        ? 'اكتملت دورة المحاكاة'
                        : 'الخزنة في وضع الاستعداد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isBackingUp ? _red : _cyan,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 280,
                child: NovaTechPanel(
                  accentColor: accent,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'سجل العمليات / SECURE TERMINAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isBackingUp ? _red : _green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isBackingUp ? _red : _green)
                                      .withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Expanded(
                        child: _processLogs.isEmpty
                            ? const Center(
                                child: Text(
                                  'بانتظار أمر بدء المحاكاة...',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              )
                            : ListView.builder(
                                controller: _logController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _processLogs.length,
                                itemBuilder: (context, index) {
                                  final last = index == _processLogs.length - 1;
                                  final line = _processLogs[index];
                                  final isWarning = line.startsWith('!');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      line,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        color: isWarning
                                            ? _red
                                            : last && _finished
                                                ? _green
                                                : _cyan.withOpacity(0.88),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        height: 1.4,
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
              const SizedBox(height: 16),
              NovaCyberButton(
                text: _isBackingUp
                    ? 'جارٍ تنفيذ المحاكاة...'
                    : 'تشغيل بروتوكول الخزنة',
                icon: _isBackingUp
                    ? Icons.lock_clock_rounded
                    : Icons.enhanced_encryption_rounded,
                color: _isBackingUp ? _red : _cyan,
                onPressed: _isBackingUp ? null : _startBackupProcess,
              ),
              const SizedBox(height: 8),
              const Text(
                'النسخ الاحتياطي الفعلي يتطلب تنفيذ تصدير من الراوتر وحفظ الملف والتحقق من سلامته.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
