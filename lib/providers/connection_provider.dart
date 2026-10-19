import 'package:flutter/material.dart';
import '../models/router_config.dart';
import '../models/pppoe_user.dart';
import '../services/mikrotik_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final MikrotikService _service = MikrotikService();

  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  
  Map<String, dynamic> _systemResource = {};
  List<dynamic> _activePPPoE = [];
  List<PPPoEUser> _pppoeUsers = [];
  List<PPPoEUser> get pppoeUsers => _pppoeUsers;

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  Map<String, dynamic> get systemResource => _systemResource;
  List<dynamic> get activePPPoE => _activePPPoE;

  Future<void> connect(RouterConfig config) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _service.connect(config);
      _systemResource = await _service.getSystemResource();
      _activePPPoE = await _service.getActivePPPoE();
      _isConnected = true;
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

  Future<void> addPPPoEUser(String username, String password, String profile) async {
    final success = await _service.createPPPoEUser(username, password, profile);
    if (success) await fetchPPPoEUsers();
  }

  Future<void> togglePPPoEUser(String id, bool disabled) async {
    final success = await _service.togglePPPoESecret(id, disabled);
    if (success) await fetchPPPoEUsers();
  }

  Future<void> deletePPPoEUser(String id) async {
    final success = await _service.removePPPoESecret(id);
    if (success) await fetchPPPoEUsers();
  }
}
