import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api/router_client.dart';
import '../core/api/routeros_client.dart' show RosException, RosErrorType;
class DashboardProvider with ChangeNotifier {
  RouterOsClient? _client;
  Timer? _timer;
  bool _isFetching = false, _disposed = false;
  String _cpuLoad = '0', _uptime = '00:00:00', _freeMemory = '0', _totalMemory = '0';
  String _boardName = 'جاري التحميل...', _version = '';
  String? _error;
  String get cpuLoad => _cpuLoad;
  String get uptime => _uptime;
  String get freeMemory => _freeMemory;
  String get totalMemory => _totalMemory;
  String get boardName => _boardName;
  String get version => _version;
  String? get error => _error;
  void attach(RouterOsClient? client) {
    if (identical(client, _client)) return;
    _client = client; _error = null;
    if (client == null) {
      stopPolling(); _cpuLoad = '0'; _uptime = '00:00:00'; _freeMemory = '0'; _totalMemory = '0'; _boardName = 'غير متصل'; _version = '';
    } else if (_timer?.isActive ?? false) { fetchResources(); }
    notifyListeners();
  }
  void startPolling() {
    if (_disposed || (_timer?.isActive ?? false)) return;
    fetchResources();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchResources());
  }
  void stopPolling() { _timer?.cancel(); _timer = null; }
  Future<void> fetchResources() async {
    final client = _client;
    if (_disposed || _isFetching || client == null) return;
    _isFetching = true;
    try {
      final dynamic response = await client.get('system/resource');
      final Map data;
      if (response is List && response.isNotEmpty && response.first is Map) data = response.first as Map;
      else if (response is Map) data = response;
      else throw const FormatException('استجابة موارد الراوتر غير متوقعة.');
      _cpuLoad = data['cpu-load']?.toString() ?? '0'; _uptime = data['uptime']?.toString() ?? '00:00:00';
      final free = int.tryParse(data['free-memory']?.toString() ?? '') ?? 0;
      final total = int.tryParse(data['total-memory']?.toString() ?? '') ?? 0;
      _freeMemory = (free / 1048576).toStringAsFixed(1); _totalMemory = (total / 1048576).toStringAsFixed(1);
      _boardName = data['board-name']?.toString() ?? 'Unknown Board'; _version = data['version']?.toString() ?? '7.x'; _error = null;
    } on RosException catch (e) { _error = e.message; }
    catch (e) { _error = 'فشل قراءة موارد الراوتر: $e'; }
    finally { _isFetching = false; if (!_disposed) notifyListeners(); }
  }
  @override
  void dispose() { _disposed = true; stopPolling(); super.dispose(); }
}