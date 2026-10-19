import '../models/router_config.dart';
import 'routeros_rest_api.dart';

class MikrotikService {
  final RouterosRestApi _api = RouterosRestApi();

  void connect(RouterConfig config) {
    _api.connect(config);
  }

  Future<Map<String, dynamic>> getSystemResource() => _api.getSystemResource();
  Future<List<dynamic>> getActivePPPoE() => _api.getActivePPPoE();
  Future<bool> createPPPoEUser(String u, String p, String prof) => _api.createPPPoEUser(u, p, prof);
}
