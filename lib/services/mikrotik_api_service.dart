import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// RouterOS v7 REST client. TLS certificate validation stays enabled by default.
class MikrotikApiService {
  MikrotikApiService({
    required String ip,
    required String port,
    required this.username,
    required this.password,
    bool useHttps = true,
    bool allowSelfSignedCertificate = false,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) : _dio = Dio(BaseOptions(
          baseUrl: '${useHttps ? 'https' : 'http'}://${_normalizeHost(ip)}:${_validatePort(port)}/rest',
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          sendTimeout: const Duration(seconds: 15),
          headers: {
            HttpHeaders.authorizationHeader:
                'Basic ${base64Encode(utf8.encode('$username:$password'))}',
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        )) {
    if (allowSelfSignedCertificate && useHttps) {
      final adapter = _dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          // Insecure by design; opt in only on a trusted LAN.
          client.badCertificateCallback =
              (X509Certificate certificate, String host, int port) => true;
          return client;
        };
      }
    }
  }

  final String username;
  final String password;
  final Dio _dio;
  bool _closed = false;

  static String _normalizeHost(String input) {
    final value = input.trim();
    if (value.isEmpty || value.contains('/') || value.contains('@')) {
      throw ArgumentError.value(input, 'ip', 'Enter a host or IP address only.');
    }
    if (value.contains(':') && !value.startsWith('[')) return '[$value]';
    return value;
  }

  static int _validatePort(String input) {
    final value = int.tryParse(input.trim());
    if (value == null || value < 1 || value > 65535) {
      throw ArgumentError.value(input, 'port', 'Port must be between 1 and 65535.');
    }
    return value;
  }

  Future<Map<String, dynamic>?> getSystemResources() async {
    final row = _firstMap(await _request(() => _dio.get<dynamic>('/system/resource')));
    return row.isEmpty ? null : row;
  }

  /// A dropped connection after reboot does not prove that it was accepted.
  Future<bool> rebootRouter() async {
    try {
      await _dio.post<dynamic>('/system/reboot', data: <String, dynamic>{});
      return true;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const MikrotikApiException(
          'انقطع الاتصال أثناء إعادة التشغيل؛ تعذّر تأكيد النتيجة.',
        );
      }
      throw _convertError('rebootRouter', error);
    }
  }

  Future<List<Map<String, dynamic>>> getActivePppoeUsers() async {
    final data = await _request(() => _dio.get<dynamic>('/ppp/active'));
    if (data is! List) return <Map<String, dynamic>>[];
    return data.whereType<Map>().map(_mapCast).toList(growable: false);
  }

  Future<Map<String, dynamic>?> pingTarget(String targetIp) async {
    final target = targetIp.trim();
    if (target.isEmpty || target.contains(' ') || target.startsWith('-')) {
      throw ArgumentError.value(targetIp, 'targetIp', 'Invalid ping target.');
    }
    final data = await _request(() => _dio.post<dynamic>(
          '/tool/ping',
          data: {'address': target, 'count': '1'},
        ));
    final row = _firstMap(data);
    return row.isEmpty ? null : row;
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() request) async {
    if (_closed) throw const MikrotikApiException('الخدمة مغلقة.');
    try {
      return (await request()).data;
    } on DioException catch (error) {
      throw _convertError('request', error);
    }
  }

  MikrotikApiException _convertError(String operation, DioException error) {
    final status = error.response?.statusCode;
    final message = switch (status) {
      401 => 'رفض الراوتر بيانات الدخول (401).',
      403 => 'حساب الراوتر لا يملك الصلاحية المطلوبة (403).',
      404 => 'مسار REST غير موجود؛ تحقق من إصدار RouterOS وصلاحيات API.',
      _ => error.type == DioExceptionType.connectionTimeout
          ? 'انتهت مهلة الاتصال بالراوتر.'
          : error.type == DioExceptionType.receiveTimeout
              ? 'انتهت مهلة انتظار رد الراوتر.'
              : error.type == DioExceptionType.connectionError
                  ? 'تعذر الاتصال. تحقق من العنوان والمنفذ وHTTPS وإتاحة REST API.'
                  : 'فشل طلب MikroTik ($operation)${status == null ? '' : ' - HTTP $status'}.',
    };
    return MikrotikApiException(message, statusCode: status);
  }

  Map<String, dynamic> _firstMap(dynamic data) {
    if (data is Map) return _mapCast(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return _mapCast(data.first as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _mapCast(Map data) =>
      data.map((key, value) => MapEntry(key.toString(), value));

  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }
}

class MikrotikApiException implements Exception {
  const MikrotikApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
