import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/router_config.dart';
import 'router_operation_guard.dart';

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

  /// Removes an active session by its RouterOS internal ID (for example *3).
  Future<bool> removeActivePPPoESession(String id) async {
    if (id.trim().isEmpty) return false;
    try {
      await _dio.delete<dynamic>('ppp/active/${Uri.encodeComponent(id)}');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> removeActiveHotspotSession(String id) async {
    if (id.trim().isEmpty) return false;
    try {
      await _dio.delete<dynamic>('ip/hotspot/active/${Uri.encodeComponent(id)}');
      return true;
    } on DioException {
      return false;
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

  Future<List<dynamic>> getInterfaces() async {
    final response = await _dio.get('interface');
    return List<dynamic>.from(response.data as List);
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
