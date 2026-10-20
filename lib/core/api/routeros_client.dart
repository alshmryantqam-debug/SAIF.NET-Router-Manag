import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

enum RosErrorType { network, timeout, tls, auth, forbidden, notFound, server, unknown }

class RosException implements Exception {
  final RosErrorType type;
  final String message;
  final int? status;
  RosException(this.type, this.message, [this.status]);
  @override
  String toString() => message;
}

class RouterOsClient {
  final String host;
  final String user;
  final String pass;
  final bool https;
  final int port;
  late final Dio _dio;

  RouterOsClient({
    required this.host,
    required this.user,
    required this.pass,
    this.https = true,
    int? port,
  }) : port = port ?? (https ? 443 : 80) {
    _dio = Dio(BaseOptions(
      baseUrl: '${https ? 'https' : 'http'}://$host:${this.port}/rest',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$pass'))}',
        'Content-Type': 'application/json',
      },
    ));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient();
        c.badCertificateCallback = (cert, h, p) => true; // شهادة المايكروتك ذاتية التوقيع
        return c;
      },
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? data]) => _send('POST', path, data: data);
  Future<dynamic> put(String path, Object data) => _send('PUT', path, data: data);
  Future<dynamic> patch(String path, Object data) => _send('PATCH', path, data: data);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Object? data, Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.request(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return r.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  RosException _map(DioException e) {
    final code = e.response?.statusCode;
    String? detail;
    final d = e.response?.data;
    if (d is Map && d['detail'] != null) detail = d['detail'].toString();

    if (code == 401) {
      return RosException(RosErrorType.auth, 'اسم المستخدم أو كلمة المرور غير صحيحة', 401);
    }
    if (code == 403) {
      return RosException(RosErrorType.forbidden,
          'صلاحيات الحساب لا تكفي. استخدم حساباً من المجموعة full', 403);
    }
    if (code == 404) {
      return RosException(RosErrorType.notFound, detail ?? 'المسار غير موجود في الراوتر', 404);
    }
    if (code != null && code >= 400) {
      return RosException(RosErrorType.server, detail ?? 'خطأ من الراوتر ($code)', code);
    }
    if (e.error is HandshakeException) {
      return RosException(RosErrorType.tls, 'فشل تفاوض TLS مع الراوتر');
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return RosException(RosErrorType.timeout, 'انتهت مهلة الاتصال بالراوتر');
      case DioExceptionType.connectionError:
        return RosException(RosErrorType.network, 'تعذر الوصول إلى الراوتر على الشبكة');
      default:
        return RosException(RosErrorType.unknown, e.message ?? 'خطأ غير معروف');
    }
  }

  void close() => _dio.close(force: true);
}
