import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

typedef RosRow = Map<String, String>;

enum RouterOsErrorKind {
  auth,
  forbidden,
  notFound,
  methodNotAllowed,
  network,
  timeout,
  ssl,
  server,
  badRequest,
  protocol,
  unknown,
}

class RouterOsException implements Exception {
  const RouterOsException(
    this.message, {
    this.kind = RouterOsErrorKind.unknown,
    this.statusCode,
  });

  final String message;
  final RouterOsErrorKind kind;
  final int? statusCode;

  bool get isAuthError =>
      kind == RouterOsErrorKind.auth || kind == RouterOsErrorKind.forbidden;

  @override
  String toString() => message;
}

bool isPrivateHost(String host) {
  final h = host.toLowerCase().trim();
  if (h == 'localhost' ||
      h.endsWith('.local') ||
      h.endsWith('.lan') ||
      h.endsWith('.home')) {
    return true;
  }
  final addr = InternetAddress.tryParse(h);
  if (addr == null) return !h.contains('.');
  if (addr.isLoopback || addr.isLinkLocal) return true;
  final b = addr.rawAddress;
  if (addr.type == InternetAddressType.IPv4) {
    if (b[0] == 10) return true;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
    if (b[0] == 192 && b[1] == 168) return true;
    if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true;
    return false;
  }
  return (b[0] & 0xFE) == 0xFC;
}

RouterOsException mapNetworkError(Object e) {
  if (e is RouterOsException) return e;
  if (e is TimeoutException) {
    return const RouterOsException(
      'انتهت مهلة الاتصال بالراوتر. تأكد من العنوان والمنفذ وأن الجدار لا يحجب الاتصال',
      kind: RouterOsErrorKind.timeout,
    );
  }
  if (e is TlsException) {
    return const RouterOsException(
      'فشل تأمين الاتصال (SSL). جرّب تعطيل SSL أو تأكد من المنفذ والشهادة',
      kind: RouterOsErrorKind.ssl,
    );
  }
  if (e is SocketException) {
    final msg = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    if (msg.contains('refused')) {
      return const RouterOsException(
        'رُفض الاتصال: الخدمة غير مفعّلة على هذا المنفذ (فعّلها من IP > Services)',
        kind: RouterOsErrorKind.network,
      );
    }
    if (msg.contains('lookup') ||
        msg.contains('resolve') ||
        msg.contains('nodename')) {
      return const RouterOsException(
        'تعذّر حلّ اسم النطاق (DNS). تحقق من الاسم أو استخدم عنوان IP',
        kind: RouterOsErrorKind.network,
      );
    }
    if (msg.contains('unreachable') || msg.contains('no route')) {
      return const RouterOsException(
        'الراوتر غير قابل للوصول. تأكد أنك على نفس الشبكة',
        kind: RouterOsErrorKind.network,
      );
    }
    if (msg.contains('timed out')) {
      return const RouterOsException(
        'انتهت مهلة الاتصال بالراوتر',
        kind: RouterOsErrorKind.timeout,
      );
    }
    return RouterOsException('تعذّر الاتصال بالراوتر: ${e.message}',
        kind: RouterOsErrorKind.network);
  }
  return RouterOsException('خطأ في الاتصال: $e');
}

class RouterOsRestApi {
  RouterOsRestApi({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.useSsl = false,
    this.timeout = const Duration(seconds: 10),
  }) {
    _dio = _buildDio();
  }

  final String host;
  final int port;
  final String username;
  final String password;
  final bool useSsl;
  final Duration timeout;

  late final Dio _dio;

  String get baseUrl {
    final h = host.contains(':') ? '[$host]' : host;
    return '${useSsl ? 'https' : 'http'}://$h:$port/rest';
  }

  Dio _buildDio() {
    final auth = base64Encode(utf8.encode('$username:$password'));
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: timeout,
      sendTimeout: timeout,
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: {
        'Authorization': 'Basic $auth',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity',
      },
    ));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String h, int p) => isPrivateHost(h);
        return client;
      },
    );
    return dio;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  /// Creates one RouterOS REST resource (RouterOS REST uses PUT for add).
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body ?? <String, dynamic>{});

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _dio.request<String>(
        path.startsWith('/') ? path : '/$path',
        data: body == null ? null : jsonEncode(body),
        queryParameters: query,
        options: Options(method: method, contentType: Headers.jsonContentType),
      );
      return _handle(res);
    } on DioException catch (e) {
      throw _mapDio(e);
    } on RouterOsException {
      rethrow;
    } catch (e) {
      throw mapNetworkError(e);
    }
  }

  dynamic _handle(Response<String> res) {
    final code = res.statusCode ?? 0;
    final raw = res.data ?? '';
    dynamic decoded;
    if (raw.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
    }
    if (code >= 200 && code < 300) return decoded;
    throw _httpError(code, decoded);
  }

  RouterOsException _httpError(int code, dynamic body) {
    String? detail;
    if (body is Map) {
      detail = (body['detail'] ?? body['message'])?.toString();
    }
    switch (code) {
      case 401:
        return RouterOsException(
          'فشل المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة (401)',
          kind: RouterOsErrorKind.auth,
          statusCode: code,
        );
      case 403:
        return RouterOsException(
          'صلاحيات المستخدم غير كافية لتنفيذ هذا الأمر (403)',
          kind: RouterOsErrorKind.forbidden,
          statusCode: code,
        );
      case 404:
        return RouterOsException(
          'المسار غير موجود (404). تأكد من تفعيل www/www-ssl وأن النسخة v7.1 أو أحدث',
          kind: RouterOsErrorKind.notFound,
          statusCode: code,
        );
      case 405:
        return RouterOsException(
          'الطريقة غير مسموحة لهذا المسار (405)',
          kind: RouterOsErrorKind.methodNotAllowed,
          statusCode: code,
        );
      case 400:
        return RouterOsException(
          'طلب غير صالح${detail == null ? '' : ': $detail'}',
          kind: RouterOsErrorKind.badRequest,
          statusCode: code,
        );
      default:
        return RouterOsException(
          'خطأ من الراوتر ($code)${detail == null ? '' : ': $detail'}',
          kind: RouterOsErrorKind.server,
          statusCode: code,
        );
    }
  }

  RouterOsException _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RouterOsException(
          'انتهت مهلة الاتصال بالراوتر. تأكد من العنوان والمنفذ',
          kind: RouterOsErrorKind.timeout,
        );
      case DioExceptionType.badCertificate:
        return const RouterOsException(
          'شهادة SSL غير موثوقة (الشهادات الذاتية مسموحة للشبكات المحلية فقط)',
          kind: RouterOsErrorKind.ssl,
        );
      case DioExceptionType.cancel:
        return const RouterOsException('أُلغي الطلب');
      default:
        final inner = e.error;
        if (inner != null) return mapNetworkError(inner);
        return RouterOsException('تعذّر الاتصال: ${e.message ?? ''}',
            kind: RouterOsErrorKind.network);
    }
  }

  void close() => _dio.close(force: true);
}