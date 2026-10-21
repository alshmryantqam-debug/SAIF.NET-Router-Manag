import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'connection_provider.dart';

/// Read-only live telemetry from the already-authenticated RouterOS REST client.
/// Credentials are deliberately not duplicated or hard-coded here.
class LiveDashboardProvider extends ChangeNotifier {
  LiveDashboardProvider(this._connectionProvider);

  ConnectionProvider _connectionProvider;
  Timer? _pollingTimer;
  bool _disposed = false;
  bool _requestInFlight = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastUpdated;

  String routerModel = 'بانتظار الاتصال';
  String uptime = '00:00:00';
  String version = '';
  double cpuLoad = 0;
  double freeMemoryMB = 0;
  double totalMemoryMB = 0;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  String get boardName => routerModel;
  String get cpuLoadText => cpuLoad.toStringAsFixed(0);
  // Compatibility aliases for the existing dashboard lifecycle.
  void startPolling() => startLiveMonitoring();
  void stopPolling() => stopLiveMonitoring();
  String get freeMemory => freeMemoryMB.toStringAsFixed(1);
  String get totalMemory => totalMemoryMB.toStringAsFixed(1);
  double get memoryUsagePercent => totalMemoryMB <= 0
      ? 0
      : ((totalMemoryMB - freeMemoryMB) / totalMemoryMB)
          .clamp(0.0, 1.0)
          .toDouble();

  void updateConnectionProvider(ConnectionProvider connectionProvider) {
    if (identical(_connectionProvider, connectionProvider)) return;
    _connectionProvider = connectionProvider;
    if (_pollingTimer?.isActive ?? false) {
      fetchResources();
    }
  }

  /// Starts one immediate read and a two-second polling loop. Duplicate starts
  /// are ignored, and requests never overlap.
  void startLiveMonitoring() {
    if (_disposed || (_pollingTimer?.isActive ?? false)) return;
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
    fetchResources();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchResources(),
    );
  }

  void stopLiveMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchResources() async {
    if (_disposed || _requestInFlight) return;
    final Dio? dio = _connectionProvider.dio;
    if (dio == null) {
      _setFailure('لا يوجد اتصال؛ اربط التطبيق بالراوتر أولاً.');
      return;
    }

    _requestInFlight = true;
    try {
      final response = await dio.get<dynamic>(
        'system/resource',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw StateError('HTTP ${response.statusCode ?? 0}');
      }

      final dynamic body = response.data;
      final Map<String, dynamic> data;
      if (body is List && body.isNotEmpty && body.first is Map) {
        data = Map<String, dynamic>.from(body.first as Map);
      } else if (body is Map) {
        data = Map<String, dynamic>.from(body);
      } else {
        throw const FormatException('تنسيق بيانات موارد الراوتر غير متوقع.');
      }

      final cpu = double.tryParse(data['cpu-load']?.toString() ?? '');
      final freeBytes = double.tryParse(data['free-memory']?.toString() ?? '');
      final totalBytes = double.tryParse(data['total-memory']?.toString() ?? '');
      if (cpu == null || freeBytes == null || totalBytes == null || totalBytes <= 0) {
        throw const FormatException('الراوتر أعاد قيماً غير صالحة للموارد.');
      }

      routerModel = data['board-name']?.toString() ?? 'MikroTik';
      uptime = data['uptime']?.toString() ?? 'غير معروف';
      version = data['version']?.toString() ?? '';
      cpuLoad = cpu.clamp(0.0, 100.0).toDouble();
      freeMemoryMB = freeBytes / 1048576;
      totalMemoryMB = totalBytes / 1048576;
      _hasError = false;
      _errorMessage = '';
      _lastUpdated = DateTime.now();
    } on TimeoutException {
      _markFailure('انتهت مهلة الاتصال بالراوتر.');
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      _markFailure(code == 401 || code == 403
          ? 'رفض الراوتر بيانات الدخول أو صلاحية REST API.'
          : 'تعذر الوصول إلى الراوتر؛ سيُعاد الاتصال تلقائياً.');
    } catch (error) {
      _markFailure(error is FormatException
          ? error.message
          : 'تعذر قراءة بيانات الراوتر؛ ستتم إعادة المحاولة.');
    } finally {
      _requestInFlight = false;
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _setFailure(String message) {
    _isLoading = false;
    _hasError = true;
    _errorMessage = message;
    if (!_disposed) notifyListeners();
  }

  void _markFailure(String message) {
    _hasError = true;
    _errorMessage = message;
  }

  @override
  void dispose() {
    _disposed = true;
    stopLiveMonitoring();
    super.dispose();
  }
}
