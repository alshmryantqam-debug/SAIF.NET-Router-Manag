import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

import '../models/router_config.dart';
import '../core/api/routeros_client.dart';
import '../core/api/connection_diagnostics.dart';
import '../models/pppoe_user.dart';
import '../models/hotspot_user.dart';
import '../services/mikrotik_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final MikrotikService _service = MikrotikService();

  Dio? _dio; // retained for compatibility with existing consumers
  RouterOsClient? _routerClient;
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

  /// Connects to RouterOS REST over HTTPS and verifies credentials by reading
  /// /system/identity. Use SSL bypass only on a trusted local management LAN.
  ///
  /// IMPORTANT: certificate validation is disabled for this client to support
  /// self-signed router certificates. Never use this configuration over public
  /// Wi-Fi or an untrusted network; production deployments should validate or
  /// pin the router certificate.
  Future<bool> connectToRouter({
    required String ip, required String port, required String username, required String password,
  }) async {
    final host=ip.trim(), parsedPort=int.tryParse(port.trim());
    if(host.isEmpty||parsedPort==null||parsedPort<1||parsedPort>65535){
      _errorMessage='أدخل عنوان IP ورقم منفذ صحيحاً.';_isConnected=false;notifyListeners();return false;
    }
    _isLoading=true;_errorMessage='';notifyListeners();
    try{
      final result=await ConnectionDiagnostics.run(host:host,user:username,pass:password,customPort:parsedPort);
      if(!result.success||result.client==null){_errorMessage=result.steps.isEmpty?'تعذر الاتصال بالراوتر.':result.steps.last.detail;_isConnected=false;return false;}
      await useClient(client:result.client!,host:host,username:username,password:password,https:result.client!.https,port:result.client!.port);
      return _isConnected;
    }catch(e){_isConnected=false;_errorMessage='تعذر الاتصال بالراوتر: $e';return false;}
    finally{_isLoading=false;notifyListeners();}
  }

  Future<void> useClient({required RouterOsClient client,required String host,required String username,required String password,required bool https,required int port}) async {
    _routerClient?.close();_routerClient=client;_isLoading=true;_errorMessage='';_isConnected=false;notifyListeners();
    try{
      final scheme=https?'https':'http';
      _service.connect(MikrotikConfig(id:'active-router',name:host,ipAddress:'$scheme://$host:$port',username:username,password:password));
      final dynamic resource=await client.get('system/resource');
      if(resource is Map){_systemResource=Map<String,dynamic>.from(resource);}
      else if(resource is List&&resource.isNotEmpty&&resource.first is Map){_systemResource=Map<String,dynamic>.from(resource.first as Map);}
      else{_systemResource={};}
      final dynamic identity=await client.get('system/identity');
      if(identity is List&&identity.isNotEmpty&&identity.first is Map){_routerIdentity=(identity.first['name']??host).toString();}
      else if(identity is Map){_routerIdentity=(identity['name']??host).toString();}
      else{_routerIdentity=host;}
      _isConnected=true;
    }on RosException catch(e){_errorMessage=e.message;_isConnected=false;_routerClient?.close();_routerClient=null;}
    catch(e){_errorMessage='فشل تحميل بيانات الراوتر: $e';_isConnected=false;_routerClient?.close();_routerClient=null;}
    finally{_isLoading=false;notifyListeners();}
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
    _routerClient?.close();
    _routerClient = null;
    _dio?.close(force: true);
    _dio = null;
    _isConnected = false;
    _isLoading = false;
    _routerIdentity = '';
    notifyListeners();
  }

  Future<void> fetchSystemResource() async {
    try {
      if (_routerClient != null) {
        final dynamic resource = await _routerClient!.get('system/resource');
        if (resource is Map) _systemResource = Map<String, dynamic>.from(resource);
        if (resource is List && resource.isNotEmpty && resource.first is Map) _systemResource = Map<String, dynamic>.from(resource.first as Map);
      } else {
        _systemResource = await _service.getSystemResource();
      }
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
