/// Common contract for RouterOS REST (v7+) and binary API (v6+) clients.
///
/// Providers should depend on this interface rather than a concrete transport,
/// so both protocols expose the same request surface.
abstract class RouterOsClient {
  /// Human-readable transport name: 'REST' or 'API'.
  String get kind;

  Future<dynamic> get(String path, {Map<String, dynamic>? query});
  Future<dynamic> post(String path, [Object? data]);
  Future<dynamic> put(String path, Object data);
  Future<dynamic> patch(String path, Object data);
  Future<dynamic> delete(String path);

  /// Releases sockets and any transport resources held by this client.
  void close();
}
