import 'dart:convert';
import 'package:dio/dio.dart';

class RouterOsRestApi {
  RouterOsRestApi(String baseUrl, String username, String password)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 7),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$username:$password'))}',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ));

  final Dio _dio;

  Exception _httpError(Response<dynamic> response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return Exception('بيانات الدخول أو صلاحيات API غير صحيحة');
    }
    return Exception('RouterOS REST HTTP ${response.statusCode}');
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
    throw Exception('وصل رد غير متوقع من الراوتر؛ لم يتم تأكيد تسجيل الدخول');
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _dio.get<dynamic>(path);
    if (response.statusCode != 200) throw _httpError(response);
    if (response.data is List) return response.data as List<dynamic>;
    if (response.data is Map) return [response.data];
    return [];
  }

  Future<List<dynamic>> hotspotUsers() => getList('/rest/ip/hotspot/user');
  Future<List<dynamic>> pppUsers() => getList('/rest/ppp/secret');
}
