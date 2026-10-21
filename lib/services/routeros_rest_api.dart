import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/router_config.dart';
import 'router_operation_guard.dart';

/// Sanitized RouterOS command failure. Never includes request headers or secrets.
class RouterOsApiException implements Exception {
  final String message;
  const RouterOsApiException(this.message);

  @override
  String toString() => message;
}

/// RouterOS REST client. Self-signed certificates are accepted only for the
/// configured router endpoint; do not use this on an untrusted network.
class RouterosRestApi {
  late final Dio _dio;
  Uri? _routerUri;

  RouterosRestApi() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    // IOHttpClientAdapter must own the HttpClient for this Dio instance.
    // The callback is restricted to the configured router host/port, while
    // allowing its self-signed certificate. It cannot fix TLS protocol or
    // network-level handshake failures unrelated to certificate validation.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate certificate, String host, int port) {
          final target = _routerUri;
          return target != null &&
              target.scheme == 'https' &&
              host.toLowerCase() == target.host.toLowerCase();
        };
        return client;
      },
    );

    _dio.interceptors.add(RouterOperationGuard());
  }

  void connect(MikrotikConfig config) {
    final configuredAddress = config.ipAddress.trim();
    final parsed = Uri.parse(
      configuredAddress.contains('://')
          ? configuredAddress
          : 'https://$configuredAddress',
    );

    if ((parsed.scheme != 'https' && parsed.scheme != 'http') ||
        parsed.host.isEmpty) {
      throw ArgumentError('Router address must be a valid HTTP(S) host.');
    }

    // HTTP is accepted only when explicitly configured by the caller (normally
    // port 80). HTTPS remains the default and is recommended for management.
    final port = parsed.hasPort ? parsed.port : (parsed.scheme == 'http' ? 80 : 443);
    _routerUri = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: port,
      path: '/rest/',
    );
    _dio.options.baseUrl = _routerUri.toString();
    _dio.options.headers = {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> getSystemResource() async {
    final response = await _dio.get('system/resource');
    final data = response.data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Unexpected RouterOS system resource response.');
  }

  Future<List<dynamic>> getPPPoESecrets() async {
    final response = await _dio.get('ppp/secret');
    return List<dynamic>.from(response.data as List);
  }

  Future<List<dynamic>> getActivePPPoE() async {
    final response = await _dio.get('ppp/active');
    return List<dynamic>.from(response.data as List);
  }

  /// Active RouterOS PPPoE sessions (not configured PPP secrets).
  Future<List<dynamic>> getActivePPPoESessions() async {
    final response = await _dio.get<dynamic>('ppp/active');
    if (response.data is! List) {
      throw const FormatException('Unexpected RouterOS PPPoE active response.');
    }
    return List<dynamic>.from(response.data as List);
  }

  Future<List<dynamic>> getActiveHotspotSessions() async {
    final response = await _dio.get<dynamic>('ip/hotspot/active');
    if (response.data is! List) {
      throw const FormatException('Unexpected RouterOS hotspot active response.');
    }
    return List<dynamic>.from(response.data as List);
  }

  /// RouterOS REST normally reports failures with an HTTP error body; the
  /// parser also recognises !trap payloads should a proxy/API adapter return one.
  void _throwIfRouterOsError(dynamic data) {
    if (data is Map) {
      final trap = data['!trap'];
      if (trap != null) {
        String detail = 'رفض الراوتر تنفيذ الأمر.';
        if (trap is List && trap.isNotEmpty && trap.first is Map) {
          final first = Map<String, dynamic>.from(trap.first as Map);
          detail = (first['message'] ?? first['category'] ?? detail).toString();
        } else if (trap is Map) {
          detail = (trap['message'] ?? trap['category'] ?? detail).toString();
        }
        throw RouterOsApiException('خطأ من الراوتر: $detail');
      }
      final error = data['error'];
      final detail = data['detail'] ?? data['message'];
      if (error != null || detail != null) {
        throw RouterOsApiException(
          'رفض الراوتر الأمر: ${(detail ?? error).toString()}',
        );
      }
    }
    if (data is List) {
      for (final row in data) {
        if (row is Map && (row.containsKey('!trap') ||
            row.containsKey('error') || row.containsKey('detail'))) {
          _throwIfRouterOsError(row);
        }
      }
    }
  }

  String _describeDioFailure(DioException error) {
    final data = error.response?.data;
    try {
      _throwIfRouterOsError(data);
    } on RouterOsApiException {
      rethrow;
    } catch (_) {
      // Continue with a safe generic message if the error body is malformed.
    }
    switch (error.response?.statusCode) {
      case 401:
      case 403:
        return 'رفض الراوتر العملية: تحقق من صلاحيات المستخدم.';
      case 404:
        return 'لم تعد الجلسة موجودة على الراوتر.';
      case 400:
        return 'رفض الراوتر صيغة الأمر أو معرّف الجلسة.';
      default:
        if (error.response == null) return 'تعذر الوصول إلى الراوتر أو انتهت مهلة الاتصال.';
        return 'فشل أمر الراوتر (رمز ${error.response?.statusCode ?? 'غير معروف'}).';
    }
  }

  /// Disconnects a live session using its RouterOS internal ID.
  /// Throws a sanitised RouterOsApiException on API/permission/trap failures.
  Future<bool> removeActivePPPoESession(String id) async {
    if (id.trim().isEmpty) {
      throw const RouterOsApiException('معرّف جلسة الاتصال غير صالح.');
    }
    try {
      final response = await _dio.delete<dynamic>(
        'ppp/active/${Uri.encodeComponent(id)}',
      );
      _throwIfRouterOsError(response.data);
      return true;
    } on DioException catch (error) {
      throw RouterOsApiException(_describeDioFailure(error));
    }
  }

  Future<bool> removeActiveHotspotSession(String id) async {
    if (id.trim().isEmpty) {
      throw const RouterOsApiException('معرّف جلسة نقطة الاتصال غير صالح.');
    }
    try {
      final response = await _dio.delete<dynamic>(
        'ip/hotspot/active/${Uri.encodeComponent(id)}',
      );
      _throwIfRouterOsError(response.data);
      return true;
    } on DioException catch (error) {
      throw RouterOsApiException(_describeDioFailure(error));
    }
  }

  Future<bool> createPPPoEUser(
      String username, String password, String profile) async {
    try {
      await _dio.put('ppp/secret', data: {
        'name': username,
        'password': password,
        'profile': profile,
        'service': 'pppoe',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removePPPoESecret(String id) async {
    try {
      await _dio.delete('ppp/secret/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> togglePPPoESecret(String id, bool disabled) async {
    try {
      await _dio.patch('ppp/secret/$id', data: {
        'disabled': disabled ? 'true' : 'false',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getHotspotUsers() async {
    final response = await _dio.get('ip/hotspot/user');
    return List<dynamic>.from(response.data as List);
  }

  Future<bool> createHotspotUser(
      String name, String password, String profile) async {
    try {
      await _dio.put('ip/hotspot/user', data: {
        'name': name,
        'password': password,
        'profile': profile,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeHotspotUser(String id) async {
    try {
      await _dio.delete('ip/hotspot/user/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Read DHCP server configuration and RouterOS logs for evidence-based review.
  Future<List<dynamic>> getDhcpServers() async {
    final response = await _dio.get<dynamic>('ip/dhcp-server');
    if (response.data is! List) {
      throw const FormatException('Unexpected DHCP server response.');
    }
    return List<dynamic>.from(response.data as List);
  }

  Future<List<dynamic>> getRouterLogs() async {
    final response = await _dio.get<dynamic>('log');
    if (response.data is! List) {
      throw const FormatException('Unexpected RouterOS log response.');
    }
    return List<dynamic>.from(response.data as List);
  }

  /// Applies an ARP mode only to a selected bridge or Ethernet interface.
  /// This can interrupt clients if static ARP entries are not complete.
  Future<bool> setInterfaceArpMode({
    required String id,
    required String type,
    required String mode,
  }) async {
    if (id.trim().isEmpty ||
        (mode != 'enabled' && mode != 'reply-only') ||
        (type != 'bridge' && type != 'ether')) {
      return false;
    }

    final menu = type == 'bridge' ? 'interface/bridge' : 'interface/ethernet';
    try {
      final response = await _dio.patch<dynamic>(
        '$menu/${Uri.encodeComponent(id)}',
        data: {'arp': mode},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException {
      return false;
    }
  }

  Future<List<dynamic>> getInterfaces() async {
    final response = await _dio.get('interface');
    return List<dynamic>.from(response.data as List);
  }

  /// Reads configured queue-tree entries; no rules are created implicitly.
  Future<List<dynamic>> getQueueTrees() async {
    final response = await _dio.get<dynamic>('queue/tree');
    if (response.data is! List) {
      throw const FormatException('Unexpected RouterOS queue-tree response.');
    }
    return List<dynamic>.from(response.data as List);
  }

  /// Updates only an existing queue-tree item by its RouterOS internal ID.
  /// maxLimit must be a positive rate such as "5M"; priority is 1..8.
  Future<void> updateQueueTree({
    required String id,
    String? maxLimit,
    int? priority,
  }) async {
    if (id.trim().isEmpty ||
        (maxLimit == null && priority == null) ||
        (priority != null && (priority < 1 || priority > 8)) ||
        (maxLimit != null &&
            !RegExp(r'^\d+(?:\.\d+)?[kKmMgG]?.hasMatch(maxLimit))) {
      throw const RouterOsApiException('إعدادات شجرة الطوابير غير صالحة.');
    }
    final data = <String, dynamic>{};
    if (maxLimit != null) data['max-limit'] = maxLimit;
    if (priority != null) data['priority'] = priority.toString();
    try {
      final response = await _dio.patch<dynamic>(
        'queue/tree/${Uri.encodeComponent(id)}',
        data: data,
      );
      _throwIfRouterOsError(response.data);
    } on DioException catch (error) {
      throw RouterOsApiException(_describeDioFailure(error));
    }
  }

  Future<List<dynamic>> getQueues() async {
    final response = await _dio.get('queue/simple');
    return List<dynamic>.from(response.data as List);
  }

  Future<List<dynamic>> getIpAddresses() async {
    final response = await _dio.get('ip/address');
    return List<dynamic>.from(response.data as List);
  }

  Future<String> _executeTemporaryScript(String source) async {
    final scriptName =
        'nova_terminal_${DateTime.now().millisecondsSinceEpoch}';
    String? scriptId;
    try {
      final created = await _dio.put('system/script', data: {
        'name': scriptName,
        'source': source,
        'policy': 'read,write,policy,test',
      });
      if (created.data is Map) {
        scriptId = created.data['.id']?.toString();
      }
      if (scriptId == null || scriptId.isEmpty) {
        final scripts = await _dio.get('system/script',
            queryParameters: {'name': scriptName});
        if (scripts.data is List && (scripts.data as List).isNotEmpty) {
          scriptId = (scripts.data as List).first['.id']?.toString();
        }
      }
      final target =
          (scriptId != null && scriptId.isNotEmpty) ? scriptId : scriptName;
      await _dio.post('system/script/run', data: {'number': target});
      return 'SUCCESS: RouterOS accepted the script for execution. REST does not provide a general interactive CLI output stream.';
    } finally {
      if (scriptId != null && scriptId.isNotEmpty) {
        try {
          await _dio.delete('system/script/$scriptId');
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  Future<bool> runSystemScript(String scriptContent) async {
    try {
      final result = await _executeTemporaryScript(scriptContent);
      return result.startsWith('SUCCESS:');
    } catch (_) {
      return false;
    }
  }

  Future<String> executeRawCommand(String command) async {
    if (command.trim().isEmpty) return 'ERROR: Command is empty.';
    try {
      return await _executeTemporaryScript(command);
    } on DioException catch (e) {
      return 'ERROR: ${e.response?.statusCode} - ${e.response?.data ?? e.message}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }
}
).hasMatch(maxLimit))) {
      throw const RouterOsApiException('إعدادات شجرة الطوابير غير صالحة.');
    }
    final data = <String, dynamic>{};
    if (maxLimit != null) data['max-limit'] = maxLimit;
    if (priority != null) data['priority'] = priority.toString();
    try {
      final response = await _dio.patch<dynamic>(
        'queue/tree/${Uri.encodeComponent(id)}',
        data: data,
      );
      _throwIfRouterOsError(response.data);
    } on DioException catch (error) {
      throw RouterOsApiException(_describeDioFailure(error));
    }
  }

  Future<List<dynamic>> getQueues() async {
    final response = await _dio.get('queue/simple');
    return List<dynamic>.from(response.data as List);
  }

  Future<List<dynamic>> getIpAddresses() async {
    final response = await _dio.get('ip/address');
    return List<dynamic>.from(response.data as List);
  }

  Future<String> _executeTemporaryScript(String source) async {
    final scriptName =
        'nova_terminal_${DateTime.now().millisecondsSinceEpoch}';
    String? scriptId;
    try {
      final created = await _dio.put('system/script', data: {
        'name': scriptName,
        'source': source,
        'policy': 'read,write,policy,test',
      });
      if (created.data is Map) {
        scriptId = created.data['.id']?.toString();
      }
      if (scriptId == null || scriptId.isEmpty) {
        final scripts = await _dio.get('system/script',
            queryParameters: {'name': scriptName});
        if (scripts.data is List && (scripts.data as List).isNotEmpty) {
          scriptId = (scripts.data as List).first['.id']?.toString();
        }
      }
      final target =
          (scriptId != null && scriptId.isNotEmpty) ? scriptId : scriptName;
      await _dio.post('system/script/run', data: {'number': target});
      return 'SUCCESS: RouterOS accepted the script for execution. REST does not provide a general interactive CLI output stream.';
    } finally {
      if (scriptId != null && scriptId.isNotEmpty) {
        try {
          await _dio.delete('system/script/$scriptId');
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  Future<bool> runSystemScript(String scriptContent) async {
    try {
      final result = await _executeTemporaryScript(scriptContent);
      return result.startsWith('SUCCESS:');
    } catch (_) {
      return false;
    }
  }

  Future<String> executeRawCommand(String command) async {
    if (command.trim().isEmpty) return 'ERROR: Command is empty.';
    try {
      return await _executeTemporaryScript(command);
    } on DioException catch (e) {
      return 'ERROR: ${e.response?.statusCode} - ${e.response?.data ?? e.message}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }
}
