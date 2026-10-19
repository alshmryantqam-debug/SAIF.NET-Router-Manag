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

  Future<Map<String, dynamic>> getSystemResource() async {
    final response = await _dio.get('/system/resource');
    return response.data;
  }

  Future<List<dynamic>> getPPPoESecrets() async {
    final response = await _dio.get('/ppp/secret');
    return response.data;
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
}