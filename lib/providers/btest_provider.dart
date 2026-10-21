import 'package:flutter/foundation.dart';

import 'connection_provider.dart';

class BtestProvider extends ChangeNotifier {
  BtestProvider(this._connection);

  final ConnectionProvider _connection;
  bool _isTesting = false;
  bool _isDisposed = false;
  double _rxSpeed = 0;
  double _txSpeed = 0;
  String _errorMessage = '';
  String _statusMessage = 'جاهز للفحص';
  int _runId = 0;
  int _lostPackets = 0;
  String _duration = '';
  String _protocol = 'udp';

  bool get isTesting => _isTesting;
  double get rxSpeed => _rxSpeed;
  double get txSpeed => _txSpeed;
  String get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  int get lostPackets => _lostPackets;
  String get duration => _duration;
  String get protocol => _protocol;

  Future<bool> startTest({
    required String targetIp,
    required String protocol,
    required String user,
    required String pass,
    required int packetSize,
    int durationSeconds = 10,
  }) async {
    if (_isTesting) return false;
    final target = targetIp.trim();
    final selectedProtocol = protocol.toLowerCase();
    if (!_connection.isConnected) {
      _errorMessage = 'اتصل براوتر الإدارة أولاً.';
      _notify();
      return false;
    }
    if (target.isEmpty ||
        !['udp', 'tcp'].contains(selectedProtocol) ||
        durationSeconds < 1 ||
        durationSeconds > 10 ||
        (selectedProtocol == 'udp' && (packetSize < 28 || packetSize > 64000))) {
      _errorMessage = 'تحقق من عنوان الهدف والبروتوكول وحجم الحزمة.';
      _notify();
      return false;
    }

    final run = ++_runId;
    _isTesting = true;
    _rxSpeed = 0;
    _txSpeed = 0;
    _lostPackets = 0;
    _errorMessage = '';
    _statusMessage = 'جارٍ تنفيذ اختبار محدود لمدة $durationSeconds ثوانٍ…';
    _duration = '$durationSeconds ث';
    _protocol = selectedProtocol;
    _notify();

    try {
      final records = await _connection.runBandwidthTest(
        address: target,
        protocol: selectedProtocol,
        user: user.trim(),
        password: pass,
        packetSize: packetSize,
        durationSeconds: durationSeconds,
      );
      if (_isDisposed || run != _runId) return false;

      final rows = records.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (rows.isEmpty) {
        throw Exception('لم يُرجع الراوتر نتائج اختبار.');
      }
      final last = rows.last;
      final status = (last['status'] ?? '').toString().toLowerCase();
      _rxSpeed = _toMbps(last['rx-current'] ?? last['rx-total-average'] ?? last['rx-10-second-average']);
      _txSpeed = _toMbps(last['tx-current'] ?? last['tx-total-average'] ?? last['tx-10-second-average']);
      _lostPackets = int.tryParse(last['lost-packets']?.toString() ?? '') ?? 0;
      if (status.isNotEmpty && status != 'done testing') {
        _errorMessage = 'انتهى الطلب بحالة غير مكتملة: ${_arabicStatus(status)}';
        _statusMessage = 'الفحص غير مكتمل';
        return false;
      }
      _statusMessage = 'اكتمل الفحص؛ النتائج من الراوتر الهدف.';
      return true;
    } catch (error) {
      if (_isDisposed || run != _runId) return false;
      _errorMessage = _safeMessage(error);
      _statusMessage = 'تعذر إكمال الفحص';
      return false;
    } finally {
      if (!_isDisposed && run == _runId) {
        _isTesting = false;
        _notify();
      }
    }
  }

  void stopTest() {
    if (!_isTesting) return;
    ++_runId;
    _isTesting = false;
    _statusMessage = 'أُرسل طلب إلغاء الاتصال؛ قد يحتاج الراوتر لحظة لإنهاء الأمر.';
    _errorMessage = '';
    _connection.cancelBandwidthTest();
    _notify();
  }

  double _toMbps(dynamic value) {
    if (value == null) return 0;
    final raw = value.toString().trim();
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*([kKmMgG]?(?:bit/s|bps|b/s)?)?$',
      caseSensitive: false).firstMatch(raw);
    if (match == null) return double.tryParse(raw) == null
        ? 0
        : (double.parse(raw) / 1000000);
    final amount = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? '').toLowerCase();
    if (unit.startsWith('g')) return amount * 1000;
    if (unit.startsWith('m')) return amount;
    if (unit.startsWith('k')) return amount / 1000;
    // RouterOS REST returns raw bit/s numbers for bandwidth-test counters.
    return amount / 1000000;
  }

  String _arabicStatus(String status) {
    switch (status) {
      case 'connecting': return 'جارٍ الاتصال';
      case 'can not start test': return 'تعذر بدء الاختبار';
      case 'can not connect': return 'تعذر الاتصال بالهدف';
      case 'remote is busy': return 'الهدف مشغول';
      case 'test unsupported': return 'الاختبار غير مدعوم';
      case 'running': return 'ما زال الاختبار جارياً';
      case 'disconnected': return 'انقطع الاتصال';
      case 'authentication failed': return 'فشل التحقق من بيانات الهدف';
      default: return status;
    }
  }

  String _safeMessage(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('password')) {
      return 'فشل التحقق من بيانات الدخول أو صلاحيات اختبار السرعة على الراوتر الهدف.';
    }
    return message.length > 240 ? '${message.substring(0, 240)}…' : message;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connection.cancelBandwidthTest();
    super.dispose();
  }
}
