/// Shared contract for RouterOS REST and binary API transports.
abstract class RouterOsClient {
  String get kind;
  String get host;
  String get user;
  String get pass;
  int get port;
  bool get https;

  Future<dynamic> get(String path, {Map<String, dynamic>? query});
  Future<dynamic> post(String path, [Object? data]);
  Future<dynamic> put(String path, Object data);
  Future<dynamic> patch(String path, Object data);
  Future<dynamic> delete(String path);

  // Existing provider-facing helpers are part of the contract so providers
  // and screens do not need protocol-specific branches.
  Future<List<dynamic>> getPPPoESecrets();
  Future<List<dynamic>> getActivePPPoE();
  Future<List<dynamic>> getHotspotUsers();
  Future<List<dynamic>> getInterfaces();
  Future<List<dynamic>> getIpAddresses();
  Future<List<dynamic>> getQueues();
  Future<void> createPPPoEUser(String username, String password, String profile);
  Future<void> togglePPPoESecret(String id, bool disabled);
  Future<void> removePPPoESecret(String id);
  Future<void> toggleHotspotUser(String id, bool disabled);
  Future<void> createHotspotUser({required String name, required String password, required String profile, String server = 'all', String comment = ''});
  Future<void> removeHotspotUser(String id);
  Future<bool> runSystemScript(String source);
  Future<String> executeRawCommand(String command);
  void close();
}
