import '../models/router_config.dart';
import 'routeros_rest_api.dart';

class MikrotikService {
  final RouterosRestApi _api = RouterosRestApi();

  void connect(MikrotikConfig config) {
    _api.connect(config);
  }

  Future<Map<String, dynamic>> getSystemResource() => _api.getSystemResource();
  Future<List<dynamic>> getActivePPPoE() => _api.getActivePPPoE();
  Future<List<dynamic>> getActivePPPoESessions() => _api.getActivePPPoESessions();
  Future<List<dynamic>> getActiveHotspotSessions() => _api.getActiveHotspotSessions();
  Future<bool> removeActivePPPoESession(String id) => _api.removeActivePPPoESession(id);
  Future<bool> removeActiveHotspotSession(String id) => _api.removeActiveHotspotSession(id);
  Future<bool> createPPPoEUser(String u, String p, String prof) => _api.createPPPoEUser(u, p, prof);
  Future<List<dynamic>> getInterfaces() => _api.getInterfaces();
  Future<List<dynamic>> getIpAddresses() => _api.getIpAddresses();
  Future<List<dynamic>> getQueues() => _api.getQueues();
  Future<String> executeRawCommand(String command) => _api.executeRawCommand(command);
  Future<bool> runSystemScript(String script) => _api.runSystemScript(script);
  Future<List<dynamic>> getPPPoESecrets() => _api.getPPPoESecrets();
  Future<bool> togglePPPoESecret(String id, bool disabled) => _api.togglePPPoESecret(id, disabled);
  Future<bool> removePPPoESecret(String id) => _api.removePPPoESecret(id);
  Future<List<dynamic>> getHotspotUsers() => _api.getHotspotUsers();
  Future<bool> removeHotspotUser(String id) => _api.removeHotspotUser(id);
}
