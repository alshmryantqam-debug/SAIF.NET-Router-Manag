import 'package:flutter/material.dart';
import '../models/router_config.dart';
import '../models/pppoe_user.dart';
import '../models/hotspot_user.dart';
import '../services/mikrotik_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final MikrotikService _service = MikrotikService();

  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  
  Map<String, dynamic> _systemResource = {};
  List<PPPoEUser> _pppoeUsers = [];
  List<HotspotUser> _hotspotUsers = [];
  List<dynamic> _interfaces = [];
  List<dynamic> _queues = [];

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  Map<String, dynamic> get systemResource => _systemResource;
  List<PPPoEUser> get pppoeUsers => _pppoeUsers;
  List<HotspotUser> get hotspotUsers => _hotspotUsers;
  List<dynamic> get interfaces => _interfaces;
  List<dynamic> get queues => _queues;

  Future<void> fetchInterfaces() async {
    try {
      _interfaces = await _service.getInterfaces();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب المنافذ: $e';
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

  Future<void> connect(RouterConfig config) async {
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
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPPPoEUsers() async {
    try {
      final data = await _service.getPPPoESecrets();
      _pppoeUsers = data.map((json) => PPPoEUser.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب المشتركين: $e';
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
    try {
      final data = await _service.getHotspotUsers();
      _hotspotUsers = data.map((json) => HotspotUser.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل جلب الهوتسبوت: $e';
      notifyListeners();
    }
  }

  Future<void> deleteHotspotUser(String id) async {
    final success = await _service.removeHotspotUser(id);
    if (success) await fetchHotspotUsers();
  }

  Future<void> addPPPoEUser(String username, String password, String profile) async {
    _errorMessage = '';
    final success = await _service.createPPPoEUser(username, password, profile);
    if (success) {
      await fetchPPPoEUsers();
    } else {
      _errorMessage = 'فشل إضافة مشترك PPPoE. تحقق من صلاحيات الراوتر والباقة.';
      notifyListeners();
    }
  }

  Future<bool> executeLoadBalancingScript(String script) async {
    return await _service.runSystemScript(script);
  }
}