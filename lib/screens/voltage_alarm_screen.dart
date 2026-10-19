import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class VoltageAlarmScreen extends ConsumerStatefulWidget {
  const VoltageAlarmScreen({super.key});

  @override
  ConsumerState<VoltageAlarmScreen> createState() => _VoltageAlarmScreenState();
}

class _VoltageAlarmScreenState extends ConsumerState<VoltageAlarmScreen> {
  static const _secure = FlutterSecureStorage();
  final _threshold = TextEditingController(text: '21.5');
  final _token = TextEditingController();
  final _chatId = TextEditingController();
  Timer? _timer;
  bool _monitoring = false;
  bool _busy = false;
  bool _alarmLatched = false;
  double? _voltage;
  String _source = '';
  String? _error;
  DateTime? _lastRead;

  @override
  void initState() {
    super.initState();
    _loadSecrets();
  }

  Future<void> _loadSecrets() async {
    _token.text = await _secure.read(key: 'saif.voltage.telegram_token') ?? '';
    _chatId.text = await _secure.read(key: 'saif.voltage.telegram_chat_id') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _threshold.dispose();
    _token.dispose();
    _chatId.dispose();
    super.dispose();
  }

  double? _readVoltage(List<Map<String, String>> rows) {
    for (final row in rows) {
      for (final entry in row.entries) {
        final key = entry.key.toLowerCase();
        if (key == 'voltage' || key == 'supply-voltage' || key == 'dc-voltage') {
          final value = double.tryParse(entry.value.replaceAll('V', '').trim());
          if (value != null && value > 0 && value < 100) {
            _source = entry.key;
            return value;
          }
        }
      }
    }
    return null;
  }

  Future<void> _checkVoltage({bool notify = true}) async {
    if (_busy || !ref.read(connectionProvider).isConnected) return;
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await ref.read(mikrotikProvider).runCommand('/system/health');
      final value = _readVoltage(rows);
      if (!mounted) return;
      setState(() { _voltage = value; _lastRead = DateTime.now(); });
      if (value == null) {
        setState(() => _error = 'الراوتر لم يُرجع قراءة فولتية من /system/health. قد لا يحتوي الجهاز على حساس فولتية؛ يلزم حساس DC خارجي يدعم SNMP/Modbus أو مراقب طاقة مستقل.');
        return;
      }
      final limit = double.tryParse(_threshold.text.trim().replaceAll(',', '.'));
      if (notify && limit != null && value < limit && !_alarmLatched) {
        _alarmLatched = true;
        await SystemSound.play(SystemSoundType.alert);
        await _sendTelegram(value, limit);
      } else if (limit != null && value >= limit + 0.5) {
        _alarmLatched = false;
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTelegram(double value, double limit) async {
    final token = _token.text.trim();
    final chatId = _chatId.text.trim();
    if (token.isEmpty || chatId.isEmpty) {
      if (mounted) setState(() => _error = 'الإنذار الصوتي يعمل، لكن لم تُضبط بيانات Telegram لإرسال الرسالة.');
      return;
    }
    try {
      await Dio().post(
        'https://api.telegram.org/bot$token/sendMessage',
        data: {
          'chat_id': chatId,
          'text': '🚨 SAIF.NET — إنذار فولتية\nالراوتر: ${ref.read(connectionProvider).activeProfile?.displayName ?? 'MikroTik'}\nالقراءة: ${value.toStringAsFixed(2)} V\nالحد الأدنى: ${limit.toStringAsFixed(2)} V\nافحص بطاريات البرج ومنظومة الطاقة الشمسية فوراً.',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إرسال Telegram: $e');
    }
  }

  Future<void> _saveTelegram() async {
    await _secure.write(key: 'saif.voltage.telegram_token', value: _token.text.trim());
    await _secure.write(key: 'saif.voltage.telegram_chat_id', value: _chatId.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حُفظت بيانات Telegram بأمان على الهاتف.')));
  }

  void _toggleMonitoring() {
    if (_monitoring) {
      _timer?.cancel();
      setState(() => _monitoring = false);
      return;
    }
    final limit = double.tryParse(_threshold.text.trim().replaceAll(',', '.'));
    if (limit == null || limit < 1 || limit > 60) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل حد فولتية صحيحاً بين 1 و60 فولت.')));
      return;
    }
    setState(() { _monitoring = true; _alarmLatched = false; });
    _checkVoltage();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkVoltage());
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final v = _voltage;
    final limit = double.tryParse(_threshold.text.trim().replaceAll(',', '.'));
    final low = v != null && limit != null && v < limit;
    return Scaffold(
      appBar: AppBar(title: const Text('إنذار فولتية البطاريات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.battery_alert_rounded, size: 34, color: Colors.white),
              const SizedBox(height: 10),
              const Text('Voltage Alarm', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(v == null ? 'بانتظار قراءة حساس الفولتية' : '${v.toStringAsFixed(2)} V', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              Text(_lastRead == null ? 'لم تتم القراءة بعد' : 'آخر قراءة: ${_lastRead!.hour.toString().padLeft(2, '0')}:${_lastRead!.minute.toString().padLeft(2, '0')}:${_lastRead!.second.toString().padLeft(2, '0')} • المصدر: $_source', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),
          _panel('مراقبة الفولتية', [
            TextField(controller: _threshold, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد الإنذار (V)', helperText: 'مثال: 21.5 فولت لنظام بطاريات 24V')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: !connected || _busy ? null : _toggleMonitoring,
              icon: Icon(_monitoring ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded),
              label: Text(_monitoring ? 'إيقاف المراقبة' : 'بدء المراقبة كل 15 ثانية'),
            )),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _busy || !connected ? null : () => _checkVoltage(notify: false), icon: const Icon(Icons.refresh_rounded), label: const Text('قراءة الآن')),
          ]),
          const SizedBox(height: 12),
          _panel('تنبيه Telegram', [
            const Text('يُخزّن رمز البوت ومعرّف المحادثة في التخزين الآمن للهاتف، ولا يُحفظان في المستودع.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: _token, obscureText: true, decoration: const InputDecoration(labelText: 'Telegram Bot Token')),
            const SizedBox(height: 10),
            TextField(controller: _chatId, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Chat ID لصاحب الشبكة')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _saveTelegram, icon: const Icon(Icons.lock_outline_rounded), label: const Text('حفظ بيانات Telegram'))),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async {
              final threshold = double.tryParse(_threshold.text.trim().replaceAll(',', '.')) ?? 21.5;
              await _sendTelegram(v ?? 0, threshold);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت محاولة إرسال رسالة الاختبار؛ تحقق من Telegram.')));
            }, icon: const Icon(Icons.send_rounded), label: const Text('إرسال رسالة اختبار')),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.danger.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.danger.withOpacity(.5))), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          ],
          if (low) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.danger.withOpacity(.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger)), child: const Text('انتباه: الفولتية أقل من الحد المحدد. افحص البطاريات والتوصيلات ومنظم الشحن.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))),
          ],
          const SizedBox(height: 12),
          const Text('مهم: المراقبة الحالية تعمل أثناء بقاء هذه الشاشة والتطبيق نشطين فقط؛ لا تضمن الإنذار إذا أُغلق التطبيق أو أوقفه Android. لضمان إنذار طوال الليل، نحتاج مراقباً دائماً يعمل على الراوتر/خادم أو حساس طاقة مستقل. كما أن CCR2116 قد لا يملك حساس فولتية لبطاريات البرج؛ لا يمكنه قياس بطارية بعيدة من دون حساس موصول.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}
