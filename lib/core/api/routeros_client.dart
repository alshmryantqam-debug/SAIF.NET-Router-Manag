import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'api_log.dart';
import 'router_client.dart';

enum RosErrorType { network, timeout, tls, auth, forbidden, notFound, server, unknown }

class RosException implements Exception {
  final RosErrorType type;
  final String message;
  final int? status;
  RosException(this.type, this.message, [this.status]);
  @override
  String toString() => message;
}

class RestClient implements RouterOsClient {
  final String host;
  final String user;
  final String pass;
  final bool https;
  final int port;
  late final Dio _dio;

  RestClient({
    required this.host,
    required this.user,
    required this.pass,
    this.https = true,
    int? port,
  }) : port = port ?? (https ? 443 : 80) {
    _dio = Dio(BaseOptions(
      baseUrl: '${https ? 'https' : 'http'}://$host:${this.port}/rest/',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$pass'))}',
        'Content-Type': 'application/json',
      },
    ));
    _dio.interceptors.add(NovaLogInterceptor());
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient();
        c.badCertificateCallback = (cert, h, p) => true; // شهادة المايكروتك ذاتية التوقيع
        return c;
      },
    );
  }

  @override
  String get kind => 'REST';

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
  @override
  Future<dynamic> post(String path, [Object? data]) => _send('POST', path, data: data);
  @override
  Future<dynamic> put(String path, Object data) => _send('PUT', path, data: data);
  @override
  Future<dynamic> patch(String path, Object data) => _send('PATCH', path, data: data);
  @override
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Object? data, Map<String, dynamic>? query}) async {
    // Retry read-only GETs only. Replaying mutations can duplicate live changes.
    const maxReadAttempts = 3;
    final canRetry = method.toUpperCase() == 'GET';
    for (var attempt = 1; ; attempt++) {
      try {
        final r = await _dio.request(
          path.replaceFirst(RegExp(r'^/+'), ''),
          data: data,
          queryParameters: query,
          options: Options(method: method),
        );
        return r.data;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final transientStatus = status == 408 || status == 429 || status == 502 || status == 503 || status == 504;
        final transientNetwork = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (canRetry && attempt < maxReadAttempts && (transientStatus || transientNetwork)) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
          continue;
        }
        throw _map(e);
      }
    }
  }

  RosException _map(DioException e) {
    final code = e.response?.statusCode;
    String? detail;
    final d = e.response?.data;
    if (d is Map) {
      final raw = d['detail'] ?? d['message'];
      if (raw != null) detail = raw.toString();
    } else if (d is String && d.trim().isNotEmpty) {
      detail = d.trim();
    }
    if (code == 400) {
      return RosException(RosErrorType.server,
          'رفض الراوتر الطلب: تحقق من الحقول والقيم وصيغة RouterOS${detail == null ? '' : '. التفاصيل: $detail'}', 400);
    }
    if (code == 401) {
      return RosException(RosErrorType.auth, 'اسم المستخدم أو كلمة المرور غير صحيحة', 401);
    }
    if (code == 403) {
      return RosException(RosErrorType.forbidden, 'صلاحيات الحساب لا تكفي لتنفيذ العملية المطلوبة.', 403);
    }
    if (code == 404) {
      return RosException(RosErrorType.notFound, detail ?? 'المسار أو العنصر غير موجود في الراوتر', 404);
    }
    if (code == 408) {
      return RosException(RosErrorType.timeout, 'انتهت مهلة طلب الراوتر (408)', 408);
    }
    if (code == 429) {
      return RosException(RosErrorType.server, 'الراوتر يطلب تقليل سرعة الطلبات (429). حاول بعد قليل.', 429);
    }
    if (code != null && code >= 500) {
      return RosException(RosErrorType.server, 'خطأ داخلي في الراوتر ($code)${detail == null ? '' : ': $detail'}', code);
    }
    if (code != null && code >= 400) {
      return RosException(RosErrorType.server, detail ?? 'رفض الراوتر الطلب ($code)', code);
    }
    if (e.error is HandshakeException) {
      return RosException(RosErrorType.tls, 'فشل تفاوض TLS مع الراوتر؛ تحقق من المنفذ والشهادة.');
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

  @override
  Future<List<dynamic>> getPPPoESecrets() async => List<dynamic>.from(await get('ppp/secret') as List);
  @override
  Future<List<dynamic>> getActivePPPoE() async => List<dynamic>.from(await get('ppp/active') as List);
  @override
  Future<List<dynamic>> getHotspotUsers() async => List<dynamic>.from(await get('ip/hotspot/user') as List);
  @override
  Future<List<dynamic>> getInterfaces() async => List<dynamic>.from(await get('interface') as List);
  @override
  Future<List<dynamic>> getIpAddresses() async => List<dynamic>.from(await get('ip/address') as List);
  @override
  Future<List<dynamic>> getQueues() async => List<dynamic>.from(await get('queue/simple') as List);
  @override
  Future<void> createPPPoEUser(String username, String password, String profile) => put('ppp/secret', {'name': username, 'password': password, 'profile': profile, 'service': 'pppoe'});
  @override
  Future<void> togglePPPoESecret(String id, bool disabled) => patch('ppp/secret/${Uri.encodeComponent(id)}', {'disabled': disabled ? 'true' : 'false'});
  @override
  Future<void> removePPPoESecret(String id) => delete('ppp/secret/${Uri.encodeComponent(id)}');
  @override
  Future<void> toggleHotspotUser(String id, bool disabled) => patch('ip/hotspot/user/${Uri.encodeComponent(id)}', {'disabled': disabled ? 'true' : 'false'});
  @override
  Future<void> createHotspotUser({required String name, required String password, required String profile, String server = 'all', String comment = ''}) =>
      put('ip/hotspot/user', {'server': server, 'name': name, 'password': password, 'profile': profile, 'comment': comment});
  @override
  Future<void> removeHotspotUser(String id) => delete('ip/hotspot/user/${Uri.encodeComponent(id)}');
  Future<void> _executeTemporaryScript(String source) async {
    final scriptName = 'nova_terminal_${DateTime.now().millisecondsSinceEpoch}';
    String? scriptId;
    try {
      final dynamic created = await put('system/script', {'name': scriptName, 'source': source, 'policy': 'read,write,policy,test'});
      if (created is Map) scriptId = created['.id']?.toString();
      if (scriptId == null || scriptId!.isEmpty) {
        final dynamic scripts = await get('system/script', query: {'name': scriptName});
        if (scripts is List && scripts.isNotEmpty && scripts.first is Map) scriptId = scripts.first['.id']?.toString();
      }
      await post('system/script/run', {'number': (scriptId != null && scriptId!.isNotEmpty) ? scriptId! : scriptName});
    } finally {
      if (scriptId != null && scriptId!.isNotEmpty) {
        try { await delete('system/script/${Uri.encodeComponent(scriptId!)}'); } catch (_) {}
      }
    }
  }
  @override
  Future<bool> runSystemScript(String source) async { await _executeTemporaryScript(source); return true; }
  @override
  Future<String> executeRawCommand(String command) async {
    if (command.trim().isEmpty) return 'ERROR: Command is empty.';
    try {
      await _executeTemporaryScript(command);
      return 'SUCCESS: RouterOS accepted the script for execution. REST does not provide a general interactive CLI output stream.';
    } on RosException catch (e) { return 'ERROR: ${e.status ?? e.type.name} - ${e.message}'; }
    catch (e) { return 'ERROR: $e'; }
  }
  @override
  void close() => _dio.close(force: true);
}
