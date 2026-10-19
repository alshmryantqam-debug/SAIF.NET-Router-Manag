import 'dart:convert';
import 'dart:io';

class RouterOsRestApi {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useHttps;

  RouterOsRestApi({
    required this.host,
    this.port = 80,
    required this.username,
    required this.password,
    this.useHttps = false,
  });

  String get _baseUrl => '${useHttps ? 'https' : 'http'}://$host:$port/rest';

  String get _basicAuth =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  HttpClient _createClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    // السماح بشهادات SSL المحلية في الراوتر
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return client;
  }

  /// تنفيذ أي أمر استعلام أو تعديل أو إضافة أو حذف حقيقي على الراوتر
  Future<dynamic> request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final client = _createClient();
    try {
      final cleanPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$_baseUrl$cleanPath');
      late HttpClientRequest req;

      switch (method.toUpperCase()) {
        case 'POST':
          req = await client.postUrl(uri);
          break;
        case 'PATCH':
          req = await client.patchUrl(uri);
          break;
        case 'PUT':
          req = await client.putUrl(uri);
          break;
        case 'DELETE':
          req = await client.deleteUrl(uri);
          break;
        default:
          req = await client.getUrl(uri);
      }

      req.headers.set(HttpHeaders.authorizationHeader, _basicAuth);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      if (body != null) {
        req.add(utf8.encode(jsonEncode(body)));
      }

      final response = await req.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.trim().isEmpty) return true;
        return jsonDecode(responseBody);
      } else {
        throw Exception('RouterOS Error (${response.statusCode}): $responseBody');
      }
    } finally {
      client.close();
    }
  }
}
