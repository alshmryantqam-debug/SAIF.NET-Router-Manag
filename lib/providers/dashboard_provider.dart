import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/router_client.dart';
import '../core/api/routeros_client.dart' show RosException;

class DashboardProvider with ChangeNotifier {
  RouterOsClient? _client;
  Timer? _timer;
  bool _isFetching = false;
  bool _disposed = false;
  DateTime? _lastHealthRead;
  DateTime? _lastClockRead;

  String _cpuLoad = '0';
  String _uptime = '00:00:00';
  String _freeMemory = '0';
  String _totalMemory = '0';
  String _boardName = 'غير متصل';
  String _version = '';
  String _cpuTemperature = 'غير متاح';
  String _voltage = 'غير متاح';
  String _routerTime = 'غير متاح';
  String _routerDate = 'غير متاح';
  int? _freeStorageBytes;
  int? _totalStorageBytes;
  String? _error;

  String get cpuLoad => _cpuLoad;
  String get uptime => _uptime;
  String get freeMemory => _freeMemory;
  String get totalMemory => _totalMemory;
  String get boardName => _boardName;
  String get version => _version;
  String get cpuTemperature => _cpuTemperature;
  String get voltage => _voltage;
  String get routerTime => _routerTime;
  String get routerDate => _routerDate;
  String? get error => _error;
  int? get freeStorageBytes => _freeStorageBytes;
  int? get totalStorageBytes => _totalStorageBytes;

  int? get usedStorageBytes {
    final total = _totalStorageBytes;
    final free = _freeStorageBytes;
    if (total == null || free == null || total <= 0 || free < 0) return null;
    return (total - free).clamp(0, total).toInt();
  }

  double? get storageUsedRatio {
    final used = usedStorageBytes;
    final total = _totalStorageBytes;
    if (used == null || total == null || total <= 0) return null;
    return (used / total).clamp(0.0, 1.0).toDouble();
  }

  void attach(RouterOsClient? client) {
    if (identical(client, _client)) return;
    _client = client;
    _error = null;
    _lastHealthRead = null;
    _lastClockRead = null;
    if (client == null) {
      stopPolling();
      _cpuLoad = '0';
      _uptime = '00:00:00';
      _freeMemory = '0';
      _totalMemory = '0';
      _boardName = 'غير متصل';
      _version = '';
      _cpuTemperature = 'غير متاح';
      _voltage = 'غير متاح';
      _routerTime = 'غير متاح';
      _routerDate = 'غير متاح';
      _freeStorageBytes = null;
      _totalStorageBytes = null;
    } else if (_timer?.isActive ?? false) {
      fetchResources();
    }
    notifyListeners();
  }

  void startPolling() {
    if (_disposed || (_timer?.isActive ?? false)) return;
    fetchResources();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => fetchResources());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchResources() async {
    final client = _client;
    if (_disposed || _isFetching || client == null) return;
    _isFetching = true;
    try {
      final dynamic response = await client.get('system/resource');
      if (!identical(client, _client)) return;
      final data = _firstMap(response);
      if (data == null) {
        throw const FormatException('استجابة موارد الراوتر غير متوقعة.');
      }

      _cpuLoad = data['cpu-load']?.toString() ?? '0';
      _uptime = data['uptime']?.toString() ?? '00:00:00';
      final freeMemory = int.tryParse(data['free-memory']?.toString() ?? '');
      final totalMemory = int.tryParse(data['total-memory']?.toString() ?? '');
      _freeMemory = freeMemory == null ? '—' : (freeMemory / 1048576).toStringAsFixed(1);
      _totalMemory = totalMemory == null ? '—' : (totalMemory / 1048576).toStringAsFixed(1);
      _boardName = data['board-name']?.toString() ?? 'غير معروف';
      _version = data['version']?.toString() ?? '';
      _freeStorageBytes = int.tryParse(data['free-hdd-space']?.toString() ?? '');
      _totalStorageBytes = int.tryParse(data['total-hdd-space']?.toString() ?? '');

      final now = DateTime.now();
      if (_lastHealthRead == null ||
          now.difference(_lastHealthRead!) >= const Duration(seconds: 12)) {
        _lastHealthRead = now;
        try {
          final dynamic health = await client.get('system/health');
          if (!identical(client, _client)) return;
          _cpuTemperature = _extractSensor(health, const ['temperature', 'temp']);
          _voltage = _extractSensor(health, const ['voltage', 'volt']);
        } catch (_) {
          _cpuTemperature = 'غير متاح';
          _voltage = 'غير متاح';
        }
      }

      if (_lastClockRead == null ||
          now.difference(_lastClockRead!) >= const Duration(seconds: 30)) {
        _lastClockRead = now;
        try {
          final dynamic clockResponse = await client.get('system/clock');
          if (!identical(client, _client)) return;
          final clock = _firstMap(clockResponse);
          _routerTime = clock?['time']?.toString() ?? 'غير متاح';
          _routerDate = clock?['date']?.toString() ?? 'غير متاح';
        } catch (_) {
          _routerTime = 'غير متاح';
          _routerDate = 'غير متاح';
        }
      }
      _error = null;
    } on RosException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'فشل قراءة موارد الراوتر: $e';
    } finally {
      _isFetching = false;
      if (!_disposed) notifyListeners();
    }
  }

  Map<String, dynamic>? _firstMap(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  String _extractSensor(dynamic response, List<String> keys) {
    final rows = response is List
        ? response
        : response is Map
            ? [response]
            : const [];
    for (final item in rows) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().toLowerCase();
      final key = (item['key'] ?? '').toString().toLowerCase();
      final label = name + ' ' + key;
      if (!keys.any(label.contains)) continue;
      final value = item['value'] ??
          item['current'] ??
          item['temperature'] ??
          item['voltage'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    if (response is Map) {
      for (final entry in response.entries) {
        final key = entry.key.toString().toLowerCase();
        if (keys.any(key.contains) && entry.value != null) {
          return entry.value.toString();
        }
      }
    }
    return 'غير متاح';
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
