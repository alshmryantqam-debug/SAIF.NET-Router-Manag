import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _pathCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_LogEntry> _log = [];
  bool _busy = false;

  static const List<_QuickCmd> _quick = [
    _QuickCmd('/ip/hotspot/user', 'مستخدمو Hotspot'),
    _QuickCmd('/ip/hotspot/active', 'النشطون Hotspot'),
    _QuickCmd('/ip/hotspot/user/profile', 'البروفايلات'),
    _QuickCmd('/ppp/secret', 'PPPoE Secrets'),
    _QuickCmd('/ppp/active', 'PPPoE Active'),
    _QuickCmd('/interface', 'الواجهات'),
    _QuickCmd('/ip/address', 'عناوين IP'),
    _QuickCmd('/ip/dhcp-server/lease', 'عقود DHCP'),
    _QuickCmd('/ip/firewall/filter', 'الجدار الناري'),
    _QuickCmd('/ip/route', 'جدول التوجيه'),
    _QuickCmd('/system/resource', 'موارد النظام'),
    _QuickCmd('/system/identity', 'هوية الراوتر'),
    _QuickCmd('/system/clock', 'الساعة'),
    _QuickCmd('/system/package', 'الحزم'),
    _QuickCmd('/log', 'السجلات'),
  ];

  @override
  void dispose() {
    _pathCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(String path) async {
    if (path.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _log.add(_LogEntry.cmd(path.trim()));
    });
    _scrollToBottom();

    try {
      final rows = await ref.read(mikrotikProvider).runCommand(path.trim());
      if (!mounted) return;
      setState(() {
        _log.add(_LogEntry.result(rows));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _log.add(_LogEntry.error(e.toString().replaceAll('Exception: ', '')));
        _busy = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _clear() {
    setState(() => _log.clear());
  }

  Future<void> _copyLog() async {
    final text = _log.map((e) => e.toPlain()).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ السجل'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: AppColors.bgCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'نسخ السجل',
            onPressed: _log.isEmpty ? null : _copyLog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            tooltip: 'مسح',
            onPressed: _log.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الإدخال
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.bgCard,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathCtrl,
                    enabled: !_busy,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: '/ip/hotspot/user',
                      prefixIcon: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                    ),
                    onSubmitted: _busy ? null : _run,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(_pathCtrl.text),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bgDeep,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 26),
                  ),
                ),
              ],
            ),
          ),

          // الأوامر السريعة
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _quick.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final q = _quick[i];
                return ActionChip(
                  label: Text(
                    q.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: _busy
                      ? null
                      : () {
                          _pathCtrl.text = q.path;
                          _run(q.path);
                        },
                  backgroundColor: AppColors.bgSurface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                );
              },
            ),
          ),

          // السجل
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF050A14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: _log.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'اكتب مساراً أو اختر أمراً سريعاً',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _log.length,
                      itemBuilder: (_, i) => _buildEntry(_log[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(_LogEntry e) {
    if (e.type == _LogType.cmd) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              r'$ ',
              style: TextStyle(
                color: AppColors.success,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Expanded(
              child: Text(
                e.text,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (e.type == _LogType.error) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '✗ ${e.text}',
          style: const TextStyle(
            color: AppColors.danger,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      );
    }

    // نتيجة
    if (e.rows == null || e.rows!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          '(لا توجد نتائج)',
          style: TextStyle(
            color: AppColors.textMuted,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: e.rows!.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${idx + 1}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...row.entries.map(
                  (kv) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${kv.key}: ${kv.value}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _LogType { cmd, result, error }

class _LogEntry {
  final _LogType type;
  final String text;
  final List<Map<String, String>>? rows;

  _LogEntry._(this.type, this.text, [this.rows]);

  factory _LogEntry.cmd(String text) => _LogEntry._(_LogType.cmd, text);
  factory _LogEntry.error(String text) => _LogEntry._(_LogType.error, text);
  factory _LogEntry.result(List<Map<String, String>> rows) =>
      _LogEntry._(_LogType.result, '', rows);

  String toPlain() {
    if (type == _LogType.cmd) return r'$ ' + text;
    if (type == _LogType.error) return '✗ $text';
    if (rows == null) return '';
    return rows!
        .map((r) => r.entries.map((e) => '${e.key}: ${e.value}').join('\n'))
        .join('\n---\n');
  }
}

class _QuickCmd {
  const _QuickCmd(this.path, this.label);
  final String path;
  final String label;
}