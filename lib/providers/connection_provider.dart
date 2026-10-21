import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

import '../models/router_config.dart';
import '../models/pppoe_user.dart';
import '../models/hotspot_user.dart';
import '../services/mikrotik_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final MikrotikService _service = MikrotikService();

  Dio? _dio;
  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  String _routerIdentity = '';

  Map<String, dynamic> _systemResource = {};
  List<PPPoEUser> _pppoeUsers = [];
  List<HotspotUser> _hotspotUsers = [];
  List<dynamic> _interfaces = [];
  List<dynamic> _ipAddresses = [];
  List<dynamic> _queues = [];

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  String get routerIdentity => _routerIdentity;
  Dio? get dio => _dio;
  Map<String, dynamic> get systemResource => _systemResource;
  List<PPPoEUser> get pppoeUsers => _pppoeUsers;
  List<HotspotUser> get hotspotUsers => _hotspotUsers;
  List<dynamic> get interfaces => _interfaces;
  List<dynamic> get ipAddresses => _ipAddresses;
  List<dynamic> get queues => _queues;

  /// Real active-session endpoints used by the sessions feature.
  Future<List<dynamic>> getActivePPPoESessions() =>
      _service.getActivePPPoESessions();

  Future<List<dynamic>> getActiveHotspotSessions() =>
      _service.getActiveHotspotSessions();

  Future<bool> removeActivePPPoESession(String id) =>
      _service.removeActivePPPoESession(id);

  Future<bool> removeActiveHotspotSession(String id) =>
      _service.removeActiveHotspotSession(id);

  Future<List<dynamic>> getInterfacesFromRouter() => _service.getInterfaces();

  Future<List<dynamic>> getQueueTrees() => _service.getQueueTrees();

  Future<void> updateQueueTree({required String id, String? maxLimit, int? priority}) => _service.updateQueueTree(id: id, maxLimit: maxLimit, priority: priority);

  Future<List<dynamic>> getDhcpServers() => _service.getDhcpServers();

  Future<List<dynamic>> getRouterLogs() => _service.getRouterLogs();

  Future<bool> setInterfaceArpMode({
    required String id,
    required String type,
    required String mode,
  }) => _service.setInterfaceArpMode(id: id, type: type, mode: mode);

  /// Connects to RouterOS REST over HTTPS and verifies credentials by reading
  /// /system/identity. Use SSL bypass only on a trusted local management LAN.
  ///
  /// IMPORTANT: certificate validation is disabled for this client to support
  /// self-signed router certificates. Never use this configuration over public
  /// Wi-Fi or an untrusted network; production deployments should validate or
  /// pin the router certificate.
  Future<bool> connectToRouter({
    required String ip,
    required String port,
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final host = ip.trim();
    final portNumber = int.tryParse(port.trim());
    if (host.isEmpty || portNumber == null || portNumber < 1 || portNumber > 65535) {
      _isLoading = false;
      _isConnected = false;
      _errorMessage = 'أدخل عنوان IP ورقم منفذ صحيحاً.';
      notifyListeners();
      return false;
    }

    _dio?.close(force: true);

    try {
      // RouterOS REST may be exposed as HTTP on port 80 or HTTPS on 443/custom port.
      // Use HTTP only when the user explicitly selects the conventional HTTP port.
      final scheme = portNumber == 80 ? 'http' : 'https';
      final credentials = base64Encode(utf8.encode('$username:$password'));
      final client = Dio(BaseOptions(
        baseUrl: '$scheme://$host:$portNumber/rest/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Basic $credentials',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ));

      if (scheme == 'https') {
        client.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final httpClient = HttpClient();
            httpClient.badCertificateCallback =
                (X509Certificate certificate, String certificateHost, int certificatePort) {
              // Accept a self-signed certificate only for this router host.
              return certificateHost.toLowerCase() == host.toLowerCase();
            };
            return httpClient;
          },
        );
      }
      _dio = client;

      final response = await client.get<dynamic>('system/identity');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('الراوتر لا يستجيب لطلب الهوية.');
      }

      final dynamic body = response.data;
      String identity = 'MikroTik Router';
      if (body is List && body.isNotEmpty && body.first is Map) {
        identity = (body.first['name'] ?? identity).toString();
      } else if (body is Map) {
        identity = (body['name'] ?? identity).toString();
      } else {
        throw const FormatException('تنسيق رد هوية الراوتر غير متوقع.');
      }

      _routerIdentity = identity;
      // Configure the existing service too, so the rest of the app's current
      // dashboard and subscriber-management methods use the same router.
      _service.connect(MikrotikConfig(
        id: 'active-router',
        name: identity,
        ipAddress: '$scheme://$host:$portNumber',
        username: username,
        password: password,
      ));

      _systemResource = await _service.getSystemResource();
      _isConnected = true;
      _errorMessage = '';
      return true;
    } on DioException catch (error) {
      _isConnected = false;
      _errorMessage = _handleDioError(error);
      _dio?.close(force: true);
      _dio = null;
      return false;
    } catch (error) {
      _isConnected = false;
      _errorMessage = 'تعذر الاتصال بالراوتر: $error';
      _dio?.close(force: true);
      _dio = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'انتهت مهلة الاتصال؛ تحقق من عنوان IP والمنفذ.';
    }
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'رفض الراوتر تسجيل الدخول؛ تحقق من اسم المستخدم وكلمة المرور وصلاحيات REST.';
    }
    if (status != null) {
      return 'فشل الاتصال (HTTP $status). تحقق من تفعيل www-ssl وخدمة REST في RouterOS.';
    }
    if (error.type == DioExceptionType.badCertificate) {
      return 'شهادة HTTPS غير مقبولة. تحقق من شبكة الإدارة وشهادة الراوتر.';
    }
    return 'تعذر الوصول إلى الراوتر. تحقق من IP والمنفذ وتفعيل www-ssl.';
  }

  void disconnect() {
    _dio?.close(force: true);
    _dio = null;
    _isConnected = false;
    _isLoading = false;
    _routerIdentity = '';
    notifyListeners();
  }

  Future<void> fetchSystemResource() async {
    try {
      _systemResource = await _service.getSystemResource();
      _errorMessage = '';
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'فشل جلب موارد الراوتر: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshDashboard() async {
    _errorMessage = '';
    try {
      await fetchPPPoEUsers();
      _systemResource = await _service.getSystemResource();
      _isConnected = true;
    } catch (e) {
      _errorMessage = 'فشل تحديث لوحة التحكم: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchInterfaces() async {
    try {
      _interfaces = await _service.getInterfaces();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب المنافذ: $e';
      notifyListeners();
    }
  }

  Future<void> fetchInterfacesAndIps() async {
    _errorMessage = '';
    try {
      final results = await Future.wait([
        _service.getInterfaces(),
        _service.getIpAddresses(),
      ]);
      _interfaces = results[0];
      _ipAddresses = results[1];
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب المنافذ وعناوين IP: $e';
      notifyListeners();
    }
  }

  Future<void> fetchQueues() async {
    try {
      _queues = await _service.getQueues();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب الطوابير: $e';
      notifyListeners();
    }
  }

  Future<void> connect(MikrotikConfig config) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _service.connect(config);
      _systemResource = await _service.getSystemResource();
      _isConnected = true;
      await fetchPPPoEUsers();
      await fetchHotspotUsers();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'فشل الاتصال بالراوتر: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPPPoEUsers() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final data = await _service.getPPPoESecrets();
      _pppoeUsers = data.map((json) => PPPoEUser.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = 'فشل جلب مشتركي PPPoE: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePPPoEUser(String id, bool disabled) async {
    final success = await _service.togglePPPoESecret(id, disabled);
    if (success) await fetchPPPoEUsers();
  }

  Future<void> deletePPPoEUser(String id) async {
    final success = await _service.removePPPoESecret(id);
    if (success) await fetchPPPoEUsers();
  }

  Future<void> fetchHotspotUsers() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final data = await _service.getHotspotUsers();
      _hotspotUsers = data.map((json) => HotspotUser.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = 'فشل جلب مستخدمي الهوتسبوت: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteHotspotUser(String id) async {
    final success = await _service.removeHotspotUser(id);
    if (success) await fetchHotspotUsers();
  }

  Future<void> addPPPoEUser(
      String username, String password, String profile) async {
    _errorMessage = '';
    final success =
        await _service.createPPPoEUser(username, password, profile);
    if (success) {
      await fetchPPPoEUsers();
    } else {
      _errorMessage =
          'فشل إضافة مشترك PPPoE. تحقق من صلاحيات الراوتر والباقة.';
      notifyListeners();
    }
  }

  Future<bool> executeLoadBalancingScript(String script) async {
    return await _service.runSystemScript(script);
  }

  Future<String> executeCommand(String command) async {
    return await _service.executeRawCommand(command);
  }
}
