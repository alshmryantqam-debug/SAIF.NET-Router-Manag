import 'dart:async';
import 'package:flutter/material.dart';
import '../models/router_config.dart';
import '../core/api/routeros_client.dart';
import '../core/api/connection_diagnostics.dart';
import '../models/pppoe_user.dart';
import '../models/hotspot_user.dart';
class ConnectionProvider extends ChangeNotifier {
  RouterOsClient? _routerClient;
  Timer? _retryTimer;
  bool _retrying = false, _manualDisconnect = false;
  String? _lastHost, _lastUsername, _lastPassword;
  int? _lastPort;
  bool _isLoading = false, _isConnected = false;
  String _errorMessage = '', _routerIdentity = '';
  Map<String, dynamic> _systemResource = {};
  List<PPPoEUser> _pppoeUsers = [];
  List<HotspotUser> _hotspotUsers = [];
  List<dynamic> _interfaces = [], _ipAddresses = [], _queues = [];
  RouterOsClient? get client => _routerClient;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  String get routerIdentity => _routerIdentity;
  Map<String, dynamic> get systemResource => _systemResource;
  List<PPPoEUser> get pppoeUsers => _pppoeUsers;
  List<HotspotUser> get hotspotUsers => _hotspotUsers;
  List<dynamic> get interfaces => _interfaces;
  List<dynamic> get ipAddresses => _ipAddresses;
  List<dynamic> get queues => _queues;

  Future<bool> connectToRouter({required String ip, required String port, required String username, required String password}) async {
    final host = ip.trim(), parsedPort = int.tryParse(port.trim());
    _manualDisconnect = false; _lastHost = host; _lastUsername = username; _lastPassword = password; _lastPort = parsedPort;
    if (host.isEmpty || parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      _errorMessage = 'أدخل عنوان IP ورقم منفذ صحيحاً.'; _isConnected = false; notifyListeners(); return false;
    }
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try {
      final result = await ConnectionDiagnostics.run(host: host, user: username, pass: password, customPort: parsedPort);
      if (!result.success || result.client == null) {
        _errorMessage = result.steps.isEmpty ? 'تعذر الاتصال بالراوتر.' : result.steps.last.detail; _isConnected = false; return false;
      }
      await useClient(client: result.client!, host: host, username: username, password: password, https: result.client!.https, port: result.client!.port);
      return _isConnected;
    } catch (e) { _isConnected = false; _errorMessage = 'تعذر الاتصال بالراوتر: $e'; return false; }
    finally { _isLoading = false; notifyListeners(); }
  }
  Future<void> useClient({required RouterOsClient client, required String host, required String username, required String password, required bool https, required int port}) async {
    _manualDisconnect = false; _lastHost = host; _lastUsername = username; _lastPassword = password; _lastPort = port;
    _retryTimer?.cancel(); _retryTimer = null;
    if (!identical(_routerClient, client)) _routerClient?.close();
    _routerClient = client; _isLoading = true; _errorMessage = ''; _isConnected = false; notifyListeners();
    try {
      final dynamic resource = await client.get('system/resource');
      if (resource is Map) _systemResource = Map<String, dynamic>.from(resource);
      else if (resource is List && resource.isNotEmpty && resource.first is Map) _systemResource = Map<String, dynamic>.from(resource.first as Map);
      else throw const FormatException('استجابة موارد الراوتر غير متوقعة.');
      final dynamic identity = await client.get('system/identity');
      if (identity is List && identity.isNotEmpty && identity.first is Map) _routerIdentity = (identity.first['name'] ?? host).toString();
      else if (identity is Map) _routerIdentity = (identity['name'] ?? host).toString();
      else _routerIdentity = host;
      _isConnected = true; _errorMessage = '';
    } on RosException catch (e) {
      _errorMessage = e.message; _isConnected = false; _routerClient?.close(); _routerClient = null; _scheduleReconnect();
    } catch (e) {
      _errorMessage = 'فشل تحميل بيانات الراوتر: $e'; _isConnected = false; _routerClient?.close(); _routerClient = null; _scheduleReconnect();
    } finally { _isLoading = false; notifyListeners(); }
  }
  Future<void> connect(MikrotikConfig config) async {
    final raw = config.ipAddress.trim();
    final uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final client = RouterOsClient(host: uri.host, user: config.username, pass: config.password, https: uri.scheme == 'https', port: port);
    await useClient(client: client, host: uri.host, username: config.username, password: config.password, https: uri.scheme == 'https', port: port);
  }
  void markConnectionLost([String? message]) {
    if (_manualDisconnect) return;
    _isConnected = false; if (message != null) _errorMessage = message;
    _routerClient?.close(); _routerClient = null; _scheduleReconnect(); notifyListeners();
  }
  void _scheduleReconnect() {
    if (_manualDisconnect || _retryTimer != null || _lastHost == null || _lastUsername == null || _lastPassword == null || _lastPort == null) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _tryReconnect());
  }
  Future<void> _tryReconnect() async {
    if (_retrying || _manualDisconnect || _isConnected || _lastHost == null || _lastUsername == null || _lastPassword == null || _lastPort == null) return;
    _retrying = true;
    try {
      final result = await ConnectionDiagnostics.run(host: _lastHost!, user: _lastUsername!, pass: _lastPassword!, customPort: _lastPort!);
      if (result.success && result.client != null && !_manualDisconnect) {
        final c = result.client!;
        await useClient(client: c, host: _lastHost!, username: _lastUsername!, password: _lastPassword!, https: c.https, port: c.port);
      }
    } catch (_) { /* Retry on the next interval. */ }
    finally { _retrying = false; }
  }
  void disconnect() {
    _manualDisconnect = true; _retryTimer?.cancel(); _retryTimer = null;
    _lastPassword = null; _lastHost = null; _lastUsername = null; _lastPort = null;
    _routerClient?.close(); _routerClient = null; _isConnected = false; _isLoading = false; _routerIdentity = '';
    _systemResource = {}; _pppoeUsers = []; _hotspotUsers = []; _interfaces = []; _ipAddresses = []; _queues = [];
    notifyListeners();
  }
  Future<void> fetchSystemResource() async {
    final c = _routerClient;
    if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try {
      final dynamic r = await c.get('system/resource');
      if (r is Map) _systemResource = Map<String, dynamic>.from(r);
      else if (r is List && r.isNotEmpty && r.first is Map) _systemResource = Map<String, dynamic>.from(r.first as Map);
      else throw const FormatException('استجابة موارد الراوتر غير متوقعة.');
      _errorMessage = ''; _isConnected = true;
    } catch (e) { _errorMessage = 'فشل جلب موارد الراوتر: $e'; _isConnected = false; }
    notifyListeners();
  }
  Future<void> refreshDashboard() async { await fetchPPPoEUsers(); await fetchSystemResource(); }
  Future<void> fetchInterfaces() async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { _interfaces = await c.getInterfaces(); _errorMessage = ''; } catch (e) { _errorMessage = 'فشل جلب المنافذ: $e'; }
    notifyListeners();
  }
  Future<void> fetchInterfacesAndIps() async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { final r = await Future.wait([c.getInterfaces(), c.getIpAddresses()]); _interfaces = r[0]; _ipAddresses = r[1]; _errorMessage = ''; }
    catch (e) { _errorMessage = 'فشل جلب المنافذ وعناوين IP: $e'; }
    notifyListeners();
  }
  Future<void> fetchQueues() async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { _queues = await c.getQueues(); _errorMessage = ''; } catch (e) { _errorMessage = 'فشل جلب الطوابير: $e'; }
    notifyListeners();
  }
  Future<void> fetchPPPoEUsers() async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try { _pppoeUsers = (await c.getPPPoESecrets()).map((e) => PPPoEUser.fromJson(Map<String, dynamic>.from(e as Map))).toList(); }
    catch (e) { _errorMessage = 'فشل جلب مشتركي PPPoE: $e'; }
    finally { _isLoading = false; notifyListeners(); }
  }
  Future<void> togglePPPoEUser(String id, bool disabled) async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { await c.togglePPPoESecret(id, disabled); await fetchPPPoEUsers(); }
    catch (e) { _errorMessage = 'تعذر تغيير حالة المشترك: $e'; notifyListeners(); }
  }
  Future<void> deletePPPoEUser(String id) async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { await c.removePPPoESecret(id); await fetchPPPoEUsers(); }
    catch (e) { _errorMessage = 'تعذر حذف المشترك: $e'; notifyListeners(); }
  }
  Future<void> fetchHotspotUsers() async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try { _hotspotUsers = (await c.getHotspotUsers()).map((e) => HotspotUser.fromJson(Map<String, dynamic>.from(e as Map))).toList(); }
    catch (e) { _errorMessage = 'فشل جلب مستخدمي الهوتسبوت: $e'; }
    finally { _isLoading = false; notifyListeners(); }
  }
  Future<void> deleteHotspotUser(String id) async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    try { await c.removeHotspotUser(id); await fetchHotspotUsers(); }
    catch (e) { _errorMessage = 'تعذر حذف بطاقة الهوتسبوت: $e'; notifyListeners(); }
  }
  Future<void> addPPPoEUser(String username, String password, String profile) async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return; }
    _errorMessage = '';
    try { await c.createPPPoEUser(username, password, profile); await fetchPPPoEUsers(); }
    catch (e) { _errorMessage = 'فشل إضافة مشترك PPPoE: $e'; notifyListeners(); }
  }
  Future<bool> executeLoadBalancingScript(String script) async {
    final c = _routerClient; if (c == null) { _errorMessage = 'اتصل بالراوتر أولاً.'; notifyListeners(); return false; }
    try { return await c.runSystemScript(script); }
    catch (e) { _errorMessage = 'فشل تنفيذ السكربت: $e'; notifyListeners(); return false; }
  }
  Future<String> executeCommand(String command) async => _routerClient?.executeRawCommand(command) ?? 'ERROR: اتصل بالراوتر أولاً.';
}