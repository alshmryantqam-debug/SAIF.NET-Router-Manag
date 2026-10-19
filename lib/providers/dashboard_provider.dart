import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'connection_provider.dart';

/// Keeps the RouterOS system-resource values used by the live dashboard.
///
/// This provider only reads /system/resource; it does not change router
/// configuration. It polls every three seconds while polling is started.
class DashboardProvider with ChangeNotifier {
  final ConnectionProvider _connectionProvider;

  Timer? _timer;
  bool _isFetching = false;
  bool _disposed = false;

  String _cpuLoad = '0';
  String _uptime = '00:00:00';
  String _freeMemory = '0';
  String _totalMemory = '0';
  String _boardName = 'جاري التحميل...';
  String _version = '';

  DashboardProvider(this._connectionProvider);

  String get cpuLoad => _cpuLoad;
  String get uptime => _uptime;
  String get freeMemory => _freeMemory;
  String get totalMemory => _totalMemory;
  String get boardName => _boardName;
  String get version => _version;

  /// Fetch immediately, then refresh every three seconds.
  /// Calling this more than once will not create duplicate timers.
  void startPolling() {
    if (_disposed || (_timer?.isActive ?? false)) return;

    fetchResources();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchResources();
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchResources() async {
    if (_disposed || _isFetching) return;

    final Dio? dio = _connectionProvider.dio;
    if (dio == null) return;

    _isFetching = true;
    try {
      final response = await dio.get<dynamic>('/system/resource');
      if (response.statusCode != 200 || response.data is! List) return;

      final List<dynamic> resources = response.data as List<dynamic>;
      if (resources.isEmpty || resources.first is! Map) return;

      final Map<dynamic, dynamic> data =
          resources.first as Map<dynamic, dynamic>;

      _cpuLoad = data['cpu-load']?.toString() ?? '0';
      _uptime = data['uptime']?.toString() ?? '00:00:00';

      // RouterOS reports memory in bytes; display values in MiB.
      final int freeMemBytes =
          int.tryParse(data['free-memory']?.toString() ?? '') ?? 0;
      final int totalMemBytes =
          int.tryParse(data['total-memory']?.toString() ?? '') ?? 0;

      _freeMemory = (freeMemBytes / 1048576).toStringAsFixed(1);
      _totalMemory = (totalMemBytes / 1048576).toStringAsFixed(1);
      _boardName = data['board-name']?.toString() ?? 'Unknown Board';
      _version = data['version']?.toString() ?? '7.x';

      if (!_disposed) notifyListeners();
    } on DioException {
      // A transient polling failure should not interrupt the dashboard.
    } catch (_) {
      // Ignore malformed/transient responses; the next poll can retry.
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
