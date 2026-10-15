import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class RouterOsRestApi {
  RouterOsRestApi(String baseUrl, String username, String password)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$username:$password'))}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        )) {
    // ✅ Allow MikroTik self-signed certificates on local networks only
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // Only trust self-signed for private/local networks
          if (host.startsWith('192.168.') ||
              host.startsWith('10.') ||
              host.startsWith('172.') ||
              host == 'localhost' ||
              host == '127.0.0.1') {
            return true;
          }
          return false;
        };
        client.connectionTimeout = const Duration(seconds: 8);
        return client;
      },
    );
  }

  final Dio _dio;

  // ═══════════════════════════════════════════════
  //  ERROR HANDLING
  // ═══════════════════════════════════════════════
  Exception _httpError(Response<dynamic> response) {
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      return Exception('بيانات الدخول أو صلاحيات API غير صحيحة');
    }
    if (code == 404) {
      return Exception('الخدمة غير مفعّلة على الراوتر (www-ssl أو REST API)');
    }
    if (code == 405) {
      return Exception('الطريقة غير مسموحة — تحقق من إصدار RouterOS');
    }
    return Exception('RouterOS HTTP $code — ${response.data}');
  }

  // ═══════════════════════════════════════════════
  //  SYSTEM
  // ═══════════════════════════════════════════════
  Future<Map<String, dynamic>> resource() async {
    final response = await _dio.get<dynamic>('/rest/system/resource');
    if (response.statusCode != 200) throw _httpError(response);
    final data = response.data;

    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      if (result.isNotEmpty) return result;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw Exception('وصل رد غير متوقع من الراوتر');
  }

  Future<Map<String, dynamic>> identity() async {
    final response = await _dio.get<dynamic>('/rest/system/identity');
    if (response.statusCode != 200) throw _httpError(response);
    final data = response.data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw Exception('وصل رد غير متوقع من الراوتر (identity)');
  }

  // ═══════════════════════════════════════════════
  //  GENERIC LIST
  // ═══════════════════════════════════════════════
  Future<List<dynamic>> getList(String path) async {
    final response = await _dio.get<dynamic>(path);
    if (response.statusCode != 200) throw _httpError(response);
    if (response.data is List) return response.data as List<dynamic>;
    if (response.data is Map) return [response.data];
    return [];
  }

  // ═══════════════════════════════════════════════
  //  HOTSPOT
  // ═══════════════════════════════════════════════
  Future<List<dynamic>> hotspotUsers() =>
      getList('/rest/ip/hotspot/user');

  Future<List<dynamic>> hotspotActive() =>
      getList('/rest/ip/hotspot/active');

  Future<List<dynamic>> hotspotProfiles() =>
      getList('/rest/ip/hotspot/user/profile');

  Future<void> addHotspotUser({
    required String name,
    required String password,
    required String profile,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'password': password,
      'profile': profile,
      if (comment != null) 'comment': comment,
    };
    final response =
        await _dio.put<dynamic>('/rest/ip/hotspot/user', data: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _httpError(response);
    }
  }

  Future<void> removeHotspotUser(String id) async {
    final response = await _dio.delete<dynamic>('/rest/ip/hotspot/user/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _httpError(response);
    }
  }

  // ═══════════════════════════════════════════════
  //  PPP
  // ═══════════════════════════════════════════════
  Future<List<dynamic>> pppUsers() =>
      getList('/rest/ppp/secret');

  Future<List<dynamic>> pppActive() =>
      getList('/rest/ppp/active');

  // ═══════════════════════════════════════════════
  //  INTERFACES
  // ═══════════════════════════════════════════════
  Future<List<dynamic>> interfaces() => getList('/rest/interface');

  Future<List<dynamic>> ipAddresses() => getList('/rest/ip/address');

  Future<List<dynamic>> dhcpLeases() => getList('/rest/ip/dhcp-server/lease');
}
