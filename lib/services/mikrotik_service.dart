import 'dart:async';

import '../models/router_config.dart';
import '../models/routeros_port_resolver.dart';
import 'routeros_rest_api.dart';
import 'routeros_binary_api.dart';

class ConnectionResult {
  final bool success;
  final String message;
  final String? identity;
  final String? version;
  final Duration latency;
  final String protocol;

  const ConnectionResult({
    required this.success,
    required this.message,
    required this.protocol,
    required this.latency,
    this.identity,
    this.version,
  });
}

class MikrotikService {
  RouterOsRestApi? _rest;
  RouterOsBinaryApi? _binary;
  RouterConfigModel? _config;

  bool get isConnected => _rest != null || _binary != null;
  String? get activeProtocol =>
      _rest != null ? 'REST' : _binary != null ? 'Binary' : null;

  // ═══════════════════════════════════════════════
  //  CONNECT — with auto-detection
  // ═══════════════════════════════════════════════
  Future<ConnectionResult> connect(RouterConfigModel c) async {
    await disconnect();
    _config = c;
    final sw = Stopwatch()..start();

    // Explicit v6
    if (c.version == 'v6') {
      return _connectBinary(c, sw);
    }

    // Explicit v7
    if (c.version == 'v7') {
      return _connectRest(c, sw);
    }

    // Auto: try REST first, fall back to Binary
    try {
      return await _connectRest(c, sw);
    } catch (restError) {
      try {
        return await _connectBinary(c, sw);
      } catch (binaryError) {
        sw.stop();
        throw Exception(
          'فشل الاتصال بالراوتر.\n'
          'REST: ${_clean(restError)}\n'
          'Binary: ${_clean(binaryError)}',
        );
      }
    }
  }

  Future<ConnectionResult> _connectRest(
    RouterConfigModel c,
    Stopwatch sw,
  ) async {
    final port = RouterOsPortResolver.restPort(configuredPort: c.port, tls: c.ssl);
    final rest = RouterOsRestApi(
      '${c.ssl ? 'https' : 'http'}://${c.host}:$port',
      c.username,
      c.password,
    );

    final identity = await rest.identity();
    final resource = await rest.resource();
    sw.stop();

    _rest = rest;
    final versionStr = resource['version']?.toString() ?? '';
    final identityStr = identity['name']?.toString() ?? 'راوتر';

    return ConnectionResult(
      success: true,
      message: 'تم الاتصال بنجاح عبر REST API',
      protocol: 'REST',
      latency: sw.elapsed,
      identity: identityStr,
      version: versionStr,
    );
  }

  Future<ConnectionResult> _connectBinary(
    RouterConfigModel c,
    Stopwatch sw,
  ) async {
    final port = RouterOsPortResolver.binaryPort(configuredPort: c.port, tls: c.ssl);
    final binary = RouterOsBinaryApi();

    await binary.connect(
      host: c.host,
      port: port,
      useSsl: c.ssl && port == 8729,
    );

    final ok = await binary.login(c.username, c.password);
    if (!ok) {
      await binary.disconnect();
      throw Exception('بيانات الدخول غير صحيحة (Binary API)');
    }

    final identity = await binary.getIdentity();
    final resource = await binary.getResource();
    sw.stop();

    _binary = binary;
    final versionStr = resource['version'] ?? '';

    return ConnectionResult(
      success: true,
      message: 'تم الاتصال بنجاح عبر Binary API',
      protocol: 'Binary',
      latency: sw.elapsed,
      identity: identity['name'] ?? 'راوتر',
      version: versionStr,
    );
  }

  String _clean(Object e) {
    final s = e.toString();
    if (s.contains('SocketException')) return 'تعذّر الوصول للراوتر';
    if (s.contains('TimeoutException')) return 'انتهت المهلة';
    if (s.contains('401')) return 'بيانات الدخول غير صحيحة';
    if (s.contains('404')) return 'الخدمة غير مفعّلة على الراوتر';
    return s.replaceAll('Exception: ', '').replaceAll('UnsupportedError: ', '');
  }

  // ═══════════════════════════════════════════════
  //  UNIFIED API
  // ═══════════════════════════════════════════════
  Future<Map<String, dynamic>> resource() async {
    if (_rest != null) return _rest!.resource();
    if (_binary != null) {
      final r = await _binary!.getResource();
      return Map<String, dynamic>.from(r);
    }
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<Map<String, dynamic>> identity() async {
    if (_rest != null) return _rest!.identity();
    if (_binary != null) {
      final r = await _binary!.getIdentity();
      return Map<String, dynamic>.from(r);
    }
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> hotspotUsers() async {
    if (_rest != null) return _rest!.hotspotUsers();
    if (_binary != null) return _binary!.getHotspotUsers();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> pppUsers() async {
    if (_rest != null) return _rest!.pppUsers();
    if (_binary != null) return _binary!.pppUsers();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> interfaces() async {
    if (_rest != null) return _rest!.interfaces();
    if (_binary != null) return _binary!.interfaces();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> interfaceListMembers() async {
    if (_rest != null) return _rest!.interfaceListMembers();
    if (_binary != null) return _binary!.interfaceListMembers();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> hotspotActive() async {
    if (_rest != null) return _rest!.hotspotActive();
    if (_binary != null) return _binary!.hotspotActive();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> pppActive() async {
    if (_rest != null) return _rest!.pppActive();
    if (_binary != null) return _binary!.pppActive();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> dhcpLeases() async {
    if (_rest != null) return _rest!.dhcpLeases();
    if (_binary != null) return _binary!.dhcpLeases();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> simpleQueues() async {
    if (_rest != null) return _rest!.simpleQueues();
    if (_binary != null) return _binary!.simpleQueues();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> ipAddresses() async {
    if (_rest != null) return _rest!.ipAddresses();
    if (_binary != null) return _binary!.ipAddresses();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> firewallFilterRules() async {
    if (_rest != null) return _rest!.firewallFilterRules();
    if (_binary != null) return _binary!.firewallFilterRules();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> firewallNatRules() async {
    if (_rest != null) return _rest!.firewallNatRules();
    if (_binary != null) return _binary!.firewallNatRules();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> firewallMangleRules() async {
    if (_rest != null) return _rest!.firewallMangleRules();
    if (_binary != null) return _binary!.firewallMangleRules();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> routes() async {
    if (_rest != null) return _rest!.routes();
    if (_binary != null) return _binary!.routes();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<List<dynamic>> logs() async {
    if (_rest != null) return _rest!.logs();
    if (_binary != null) return _binary!.logs();
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<void> addHotspotUser({
    required String name,
    required String password,
    required String profile,
    String? comment,
  }) async {
    if (_rest != null) {
      await _rest!.addHotspotUser(
        name: name,
        password: password,
        profile: profile,
        comment: comment,
      );
      return;
    }
    if (_binary != null) {
      await _binary!.addHotspotUser(
        name: name,
        password: password,
        profile: profile,
        comment: comment,
      );
      return;
    }
    throw Exception('اتصل بالراوتر أولاً');
  }

  Future<void> disconnect() async {
    try {
      await _binary?.disconnect();
    } catch (_) {}
    _rest = null;
    _binary = null;
    _config = null;
  }
}
