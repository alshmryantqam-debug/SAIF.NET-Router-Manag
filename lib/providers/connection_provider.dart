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
}
