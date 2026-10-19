import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/router_config.dart';
import '../core/security/router_operation_guard.dart';

class RouterosRestApi {
  late Dio _dio;

  RouterosRestApi() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(RouterOperationGuard());
  }

  void connect(RouterConfig config) {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    _dio.options.baseUrl = 'https://${config.ipAddress}/rest';
    _dio.options.headers = {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
    };
  }

  // قراءة
  Future<Map<String, dynamic>> getSystemResource() async {
    final response = await _dio.get('/system/resource');
    return response.data;
  }

  Future<List<dynamic>> getActivePPPoE() async {
    final response = await _dio.get('/ppp/active');
    return response.data;
  }

  // إدارة (كتابة)
  Future<bool> createPPPoEUser(String username, String password, String profile) async {
    try {
      await _dio.put('/ppp/secret', data: {
        'name': username,
        'password': password,
        'profile': profile,
        'service': 'pppoe',
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
