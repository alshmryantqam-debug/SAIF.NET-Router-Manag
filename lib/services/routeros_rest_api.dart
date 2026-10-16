import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

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
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        return client;
      },
    );
  }

  final Dio _dio;

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
    return Exception('RouterOS HTTP $code');
  }

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

  Future<List<dynamic>> getList(String path) async {
    final response = await _dio.get<dynamic>(path);
    if (response.statusCode != 200) throw _httpError(response);
    if (response.data is List) return response.data as List<dynamic>;
    if (response.data is Map) return [response.data];
    return [];
  }

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

  Future<List<dynamic>> pppUsers() =>
      getList('/rest/ppp/secret');

  Future<List<dynamic>> pppActive() =>
      getList('/rest/ppp/active');

  Future<List<dynamic>> interfaces() => getList('/rest/interface');

  Future<List<dynamic>> interfaceListMembers() => getList('/rest/interface/list/member');

  Future<List<dynamic>> ipAddresses() => getList('/rest/ip/address');

  Future<List<dynamic>> dhcpLeases() =>
      getList('/rest/ip/dhcp-server/lease');

  Future<List<dynamic>> simpleQueues() =>
      getList('/rest/queue/simple');

  Future<List<dynamic>> firewallFilterRules() =>
      getList('/rest/ip/firewall/filter');

  Future<List<dynamic>> firewallNatRules() =>
      getList('/rest/ip/firewall/nat');

  Future<List<dynamic>> firewallMangleRules() =>
      getList('/rest/ip/firewall/mangle');

  Future<List<dynamic>> routes() => getList('/rest/ip/route');

  Future<List<dynamic>> logs() => getList('/rest/log');
}
