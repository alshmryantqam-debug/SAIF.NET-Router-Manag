import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/router_config.dart';

class RouterosRestApi {
  late Dio _dio;

  RouterosRestApi() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  void connect(MikrotikConfig config) {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    _dio.options.baseUrl = 'https://${config.ipAddress}/rest';
    _dio.options.headers = {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> getSystemResource() async {
    final response = await _dio.get('/system/resource');
    return response.data;
  }

  Future<List<dynamic>> getPPPoESecrets() async {
    final response = await _dio.get('/ppp/secret');
    return response.data;
  }

  Future<List<dynamic>> getActivePPPoE() async {
    final response = await _dio.get('/ppp/active');
    return response.data;
  }

  Future<bool> createPPPoEUser(String username, String password, String profile) async {
    try {
      await _dio.put('/ppp/secret', data: {
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
      await _dio.delete('/ppp/secret/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> togglePPPoESecret(String id, bool disabled) async {
    try {
      await _dio.patch('/ppp/secret/$id', data: {
        'disabled': disabled ? 'true' : 'false',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getHotspotUsers() async {
    final response = await _dio.get('/ip/hotspot/user');
    return response.data;
  }

  Future<bool> createHotspotUser(String name, String password, String profile) async {
    try {
      await _dio.put('/ip/hotspot/user', data: {
        'name': name,
        'password': password,
        'profile': profile,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeHotspotUser(String id) async {
    try {
      await _dio.delete('/ip/hotspot/user/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getInterfaces() async {
    final response = await _dio.get('/interface');
    return response.data;
  }

  Future<List<dynamic>> getQueues() async {
    final response = await _dio.get('/queue/simple');
    return response.data;
  }

  Future<List<dynamic>> getIpAddresses() async {
    final response = await _dio.get('/ip/address');
    return response.data;
  }

  Future<String> _executeTemporaryScript(String source) async {
    final scriptName = 'nova_terminal_${DateTime.now().millisecondsSinceEpoch}';
    String? scriptId;
    try {
      final created = await _dio.put('/system/script', data: {
        'name': scriptName,
        'source': source,
        'policy': 'read,write,policy,test',
      });
      if (created.data is Map) {
        scriptId = created.data['.id']?.toString();
      }
      if (scriptId == null || scriptId!.isEmpty) {
        final scripts = await _dio.get('/system/script', queryParameters: {'name': scriptName});
        if (scripts.data is List && (scripts.data as List).isNotEmpty) {
          scriptId = (scripts.data as List).first['.id']?.toString();
        }
      }
      final target = (scriptId != null && scriptId!.isNotEmpty) ? scriptId! : scriptName;
      await _dio.post('/system/script/run', data: {'number': target});
      return 'SUCCESS: RouterOS accepted the script for execution. REST does not provide a general interactive CLI output stream.';
    } finally {
      if (scriptId != null && scriptId!.isNotEmpty) {
        try {
          await _dio.delete('/system/script/$scriptId');
        } catch (_) {
          // Cleanup is best-effort; the execution result remains authoritative.
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