import 'dart:async';

import '../models/hotspot_user.dart';
import '../models/pppoe_user.dart';
import '../models/router_config.dart';
import '../core/security/router_operation_guard.dart';
import 'routeros_binary_api.dart';
import 'routeros_rest_api.dart';

enum ApiProtocol { rest, binary }

extension ApiProtocolX on ApiProtocol {
  String get label => this == ApiProtocol.rest ? 'REST API' : 'Binary API';
}

bool _b(String? v) => v == 'true' || v == 'yes';
int _i(String? v) => int.tryParse(v ?? '') ?? 0;

class SystemResource {
  const SystemResource({
    this.uptime = '',
    this.version = '',
    this.boardName = '',
    this.architecture = '',
    this.cpuLoad = 0,
    this.cpuCount = 0,
    this.cpuFrequency = 0,
    this.freeMemory = 0,
    this.totalMemory = 0,
    this.freeHdd = 0,
    this.totalHdd = 0,
  });

  final String uptime;
  final String version;
  final String boardName;
  final String architecture;
  final int cpuLoad;
  final int cpuCount;
  final int cpuFrequency;
  final int freeMemory;
  final int totalMemory;
  final int freeHdd;
  final int totalHdd;

  double get memUsedPercent => totalMemory <= 0
      ? 0
      : ((totalMemory - freeMemory) / totalMemory * 100).clamp(0, 100);

  factory SystemResource.fromRow(RosRow r) => SystemResource(
        uptime: r['uptime'] ?? '',
        version: r['version'] ?? '',
        boardName: r['board-name'] ?? '',
        architecture: r['architecture-name'] ?? '',
        cpuLoad: _i(r['cpu-load']),
        cpuCount: _i(r['cpu-count']),
        cpuFrequency: _i(r['cpu-frequency']),
        freeMemory: _i(r['free-memory']),
        totalMemory: _i(r['total-memory']),
        freeHdd: _i(r['free-hdd-space']),
        totalHdd: _i(r['total-hdd-space']),
      );
}

class InterfaceInfo {
  const InterfaceInfo({
    required this.id,
    required this.name,
    this.type = '',
    this.running = false,
    this.disabled = false,
    this.comment = '',
    this.mac = '',
    this.mtu = '',
    this.rxByte = 0,
    this.txByte = 0,
  });

  final String id;
  final String name;
  final String type;
  final bool running;
  final bool disabled;
  final String comment;
  final String mac;
  final String mtu;
  final int rxByte;
  final int txByte;

  factory InterfaceInfo.fromRow(RosRow r) => InterfaceInfo(
        id: r['.id'] ?? '',
        name: r['name'] ?? '',
        type: r['type'] ?? '',
        running: _b(r['running']),
        disabled: _b(r['disabled']),
        comment: r['comment'] ?? '',
        mac: r['mac-address'] ?? '',
        mtu: r['actual-mtu'] ?? r['mtu'] ?? '',
        rxByte: _i(r['rx-byte']),
        txByte: _i(r['tx-byte']),
      );
}

class IpAddressInfo {
  const IpAddressInfo({
    required this.id,
    required this.address,
    this.network = '',
    this.interfaceName = '',
    this.disabled = false,
    this.dynamic = false,
    this.comment = '',
  });

  final String id;
  final String address;
  final String network;
  final String interfaceName;
  final bool disabled;
  final bool dynamic;
  final String comment;

  factory IpAddressInfo.fromRow(RosRow r) => IpAddressInfo(
        id: r['.id'] ?? '',
        address: r['address'] ?? '',
        network: r['network'] ?? '',
        interfaceName: r['interface'] ?? '',
        disabled: _b(r['disabled']),
        dynamic: _b(r['dynamic']),
        comment: r['comment'] ?? '',
      );
}

class DhcpLease {
  const DhcpLease({
    required this.id,
    required this.address,
    this.mac = '',
    this.hostName = '',
    this.status = '',
    this.server = '',
    this.expiresAfter = '',
    this.comment = '',
    this.dynamic = false,
  });

  final String id;
  final String address;
  final String mac;
  final String hostName;
  final String status;
  final String server;
  final String expiresAfter;
  final String comment;
  final bool dynamic;

  factory DhcpLease.fromRow(RosRow r) => DhcpLease(
        id: r['.id'] ?? '',
        address: r['address'] ?? '',
        mac: r['mac-address'] ?? '',
        hostName: r['host-name'] ?? '',
        status: r['status'] ?? '',
        server: r['server'] ?? '',
        expiresAfter: r['expires-after'] ?? '',
        comment: r['comment'] ?? '',
        dynamic: _b(r['dynamic']),
      );

  bool get isBound => status == 'bound';
}

class FirewallRule {
  const FirewallRule({
    required this.id,
    this.chain = '',
    this.action = '',
    this.protocol = '',
    this.srcAddress = '',
    this.dstAddress = '',
    this.dstPort = '',
    this.inInterface = '',
    this.outInterface = '',
    this.comment = '',
    this.disabled = false,
    this.bytes = 0,
    this.packets = 0,
  });

  final String id;
  final String chain;
  final String action;
  final String protocol;
  final String srcAddress;
  final String dstAddress;
  final String dstPort;
  final String inInterface;
  final String outInterface;
  final String comment;
  final bool disabled;
  final int bytes;
  final int packets;

  factory FirewallRule.fromRow(RosRow r) => FirewallRule(
        id: r['.id'] ?? '',
        chain: r['chain'] ?? '',
        action: r['action'] ?? '',
        protocol: r['protocol'] ?? '',
        srcAddress: r['src-address'] ?? '',
        dstAddress: r['dst-address'] ?? '',
        dstPort: r['dst-port'] ?? '',
        inInterface: r['in-interface'] ?? '',
        outInterface: r['out-interface'] ?? '',
        comment: r['comment'] ?? '',
        disabled: _b(r['disabled']),
        bytes: _i(r['bytes']),
        packets: _i(r['packets']),
      );
}

class ConnectionResult {
  const ConnectionResult({
    required this.success,
    required this.message,
    required this.protocol,
    required this.latencyMs,
    this.identity = '',
    this.version = '',
    this.boardName = '',
  });

  final bool success;
  final String message;
  final ApiProtocol protocol;
  final int latencyMs;
  final String identity;
  final String version;
  final String boardName;
}

class MikrotikService {
  RouterOsRestApi? _rest;
  RouterOsBinaryApi? _binary;
  RouterProfile? _profile;
  ApiProtocol? _activeProtocol;

  bool get isConnected => _rest != null || _binary != null;
  ApiProtocol? get activeProtocol => _activeProtocol;
  RouterProfile? get profile => _profile;

  Future<ConnectionResult> connect(RouterProfile p) async {
    await disconnect();
    _profile = p;
    final sw = Stopwatch()..start();

    if (p.version == RouterVersion.v6) {
      return _connectBinary(p, sw);
    }
    if (p.version == RouterVersion.v7) {
      return _connectRest(p, sw);
    }

    Object? restError;
    try {
      return await _connectRest(p, sw);
    } catch (e) {
      restError = e;
    }

    try {
      final result = await _connectBinary(p, sw);
      _profile = p.copyWith(lastDetected: RouterVersion.v6);
      return result;
    } catch (binaryError) {
      sw.stop();
      throw RouterOsException(
        'فشل الاتصال بالراوتر عبر الطريقتين.\n'
        'REST (v7): ${_cleanMessage(restError)}\n'
        'Binary (v6): ${_cleanMessage(binaryError)}',
        kind: RouterOsErrorKind.network,
      );
    }
  }

  Future<ConnectionResult> _connectRest(
    RouterProfile p,
    Stopwatch sw,
  ) async {
    final restPort = p.restPort > 0 ? p.restPort : (p.useSsl ? 443 : 80);

    final client = RouterOsRestApi(
      host: p.host,
      port: restPort,
      username: p.username,
      password: p.password,
      useSsl: p.useSsl,
    );

    try {
      final res = await client.get('/system/resource');
      final id = await client.get('/system/identity');

      sw.stop();
      _rest = client;
      _activeProtocol = ApiProtocol.rest;

      final resource = _extractMap(res);
      final identity = _extractMap(id);

      return ConnectionResult(
        success: true,
        message: 'تم الاتصال بنجاح عبر REST API',
        protocol: ApiProtocol.rest,
        latencyMs: sw.elapsedMilliseconds,
        identity: identity['name']?.toString() ?? 'راوتر',
        version: resource['version']?.toString() ?? '',
        boardName: resource['board-name']?.toString() ?? '',
      );
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<ConnectionResult> _connectBinary(
    RouterProfile p,
    Stopwatch sw,
  ) async {
    final apiPort = p.apiPort > 0 ? p.apiPort : 8728;
    final useSsl = p.useSsl && apiPort == 8729;

    final client = await RouterOsBinaryApi.connect(
      host: p.host,
      port: apiPort,
      username: p.username,
      password: p.password,
      useSsl: useSsl,
    );

    try {
      final resource = await client.getResource();
      final identity = await client.getIdentity();

      sw.stop();
      _binary = client;
      _activeProtocol = ApiProtocol.binary;

      return ConnectionResult(
        success: true,
        message: 'تم الاتصال بنجاح عبر Binary API',
        protocol: ApiProtocol.binary,
        latencyMs: sw.elapsedMilliseconds,
        identity: identity.isEmpty ? 'راوتر' : identity,
        version: resource['version'] ?? '',
        boardName: resource['board-name'] ?? '',
      );
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return <String, dynamic>{};
  }

  String _cleanMessage(Object? e) {
    if (e == null) return 'خطأ غير معروف';
    if (e is RouterOsException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<SystemResource> systemResource() async {
    if (_rest != null) {
      final res = await _rest!.get('/system/resource');
      return SystemResource.fromRow(_toRow(_extractMap(res)));
    }
    if (_binary != null) {
      final row = await _binary!.getResource();
      return SystemResource.fromRow(row);
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  Future<String> systemIdentity() async {
    if (_rest != null) {
      final res = await _rest!.get('/system/identity');
      return _extractMap(res)['name']?.toString() ?? '';
    }
    if (_binary != null) return _binary!.getIdentity();
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  RosRow _toRow(Map<String, dynamic> m) {
    return m.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  Future<List<HotspotUser>> hotspotUsers() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/hotspot/user');
      return _asList(data)
          .map((e) => HotspotUser.fromRow(_toRow(e)))
          .toList();
    }
    if (_binary != null) {
      final rows = await _binary!.getHotspotUsers();
      return rows.map(HotspotUser.fromRow).toList();
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  Future<List<Map<String, String>>> hotspotActive() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/hotspot/active');
      return _asList(data).map(_toRow).toList();
    }
    if (_binary != null) {
      final rows = await _binary!.command('/ip/hotspot/active/print');
      return rows.map((row) => Map<String, String>.from(row)).toList();
    }
    throw const RouterOsException(
      'اتصل بالراوتر أولاً',
      kind: RouterOsErrorKind.network,
    );
  }

  Future<List<Map<String, String>>> hotspotProfiles() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/hotspot/user/profile');
      return _asList(data).map(_toRow).toList();
    }
    return [];
  }

  Future<void> addHotspotUser(HotspotUser user) async {
    if (_rest != null) {
      await _rest!.post('/ip/hotspot/user', user.toParams());
      return;
    }
    if (_binary != null) {
      await _binary!.addHotspotUser(
        name: user.name,
        password: user.password,
        profile: user.profile,
        comment: user.comment,
        limitUptime: user.limitUptime,
        limitBytesTotal: user.limitBytesTotal,
      );
      return;
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  Future<void> removeHotspotUser(String id) async {
    if (_rest != null) {
      await _rest!.delete('/ip/hotspot/user/$id');
      return;
    }
    throw const RouterOsException('الحذف يتطلب REST API (v7)',
        kind: RouterOsErrorKind.methodNotAllowed);
  }

  Future<void> updateHotspotUser(String id, Map<String, dynamic> data) async {
    if (_rest != null) {
      await _rest!.patch('/ip/hotspot/user/$id', data);
      return;
    }
    throw const RouterOsException('التعديل يتطلب REST API (v7)',
        kind: RouterOsErrorKind.methodNotAllowed);
  }

  Future<void> setHotspotUserDisabled(String id, bool disabled) async {
    await updateHotspotUser(id, {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  Future<List<PppoeUser>> pppoeSecrets() async {
    if (_rest != null) {
      final data = await _rest!.get('/ppp/secret');
      return _asList(data).map((e) => PppoeUser.fromRow(_toRow(e))).toList();
    }
    if (_binary != null) {
      final rows = await _binary!.command('/ppp/secret/print');
      return rows.map(PppoeUser.fromRow).toList();
    }
    return [];
  }

  Future<List<PppoeActive>> pppoeActive() async {
    if (_rest != null) {
      final data = await _rest!.get('/ppp/active');
      return _asList(data).map((e) => PppoeActive.fromRow(_toRow(e))).toList();
    }
    if (_binary != null) {
      final rows = await _binary!.command('/ppp/active/print');
      return rows.map(PppoeActive.fromRow).toList();
    }
    throw const RouterOsException(
      'اتصل بالراوتر أولاً',
      kind: RouterOsErrorKind.network,
    );
  }

  Future<void> addPppoeUser(PppoeUser user) async {
    if (_rest != null) {
      await _rest!.post('/ppp/secret', user.toParams());
      return;
    }
    throw const RouterOsException('الإضافة تتطلب REST API (v7)',
        kind: RouterOsErrorKind.methodNotAllowed);
  }

  Future<void> removePppoeUser(String id) async {
    if (_rest != null) {
      await _rest!.delete('/ppp/secret/$id');
      return;
    }
    throw const RouterOsException('الحذف يتطلب REST API (v7)',
        kind: RouterOsErrorKind.methodNotAllowed);
  }

  Future<void> setPppoeUserDisabled(String id, bool disabled) async {
    if (_rest != null) {
      await _rest!.patch('/ppp/secret/$id', {
        'disabled': disabled ? 'true' : 'false',
      });
      return;
    }
    throw const RouterOsException('التعديل يتطلب REST API (v7)',
        kind: RouterOsErrorKind.methodNotAllowed);
  }

  Future<List<InterfaceInfo>> interfaces() async {
    if (_rest != null) {
      final data = await _rest!.get('/interface');
      return _asList(data)
          .map((e) => InterfaceInfo.fromRow(_toRow(e)))
          .toList();
    }
    return [];
  }

  Future<List<IpAddressInfo>> ipAddresses() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/address');
      return _asList(data)
          .map((e) => IpAddressInfo.fromRow(_toRow(e)))
          .toList();
    }
    return [];
  }

  Future<List<DhcpLease>> dhcpLeases() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/dhcp-server/lease');
      return _asList(data).map((e) => DhcpLease.fromRow(_toRow(e))).toList();
    }
    return [];
  }

  Future<List<FirewallRule>> firewallRules() async {
    if (_rest != null) {
      final data = await _rest!.get('/ip/firewall/filter');
      return _asList(data)
          .map((e) => FirewallRule.fromRow(_toRow(e)))
          .toList();
    }
    return [];
  }

  /// Reads simple queues and returns RouterOS fields without changing them.
  Future<List<Map<String, String>>> simpleQueues() async {
    if (_rest != null) {
      final data = await _rest!.get('/queue/simple');
      return _asList(data).map(_toRow).toList();
    }
    if (_binary != null) {
      final rows = await _binary!.command('/queue/simple/print');
      return rows.map((row) => Map<String, String>.from(row)).toList();
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  /// Updates an existing simple queue's upload/download limits.
  /// Values must be RouterOS rate strings, e.g. 10M/20M.
  Future<void> updateSimpleQueueLimits(
    String id, {
    required String maxLimit,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تعديل حدود Queue متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty || !_isValidRatePair(maxLimit)) {
      throw const RouterOsException(
        'حد السرعة غير صالح. استخدم صيغة مثل 10M/20M (رفع/تنزيل).',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await _rest!.patch('/queue/simple/$id', {'max-limit': maxLimit.trim()});
  }

  bool _isValidRatePair(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 2) return false;
    final rate = RegExp(r'^(?:0|[1-9][0-9]*)(?:[kKmMgG])?
  Future<void> setInterfaceDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تغيير الواجهات متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف الواجهة غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/interface/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Enables/disables an existing firewall filter rule; does not create rules.
  Future<void> setFirewallRuleDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تعديل قواعد الجدار الناري متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف قاعدة الجدار الناري غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/ip/firewall/filter/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Enables/disables a simple queue. Does not rewrite queue limits.
  Future<void> setSimpleQueueDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تعديل Simple Queue متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف Queue غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/queue/simple/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  void _requireWriteApproval({
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (!isConnected) {
      throw const RouterOsException('اتصل بالراوتر أولاً.',
          kind: RouterOsErrorKind.network);
    }
  }

  static const Set<String> _readOnlyCommandPaths = {
    '/ip/hotspot/user',
    '/ip/hotspot/active',
    '/ip/hotspot/user/profile',
    '/ppp/secret',
    '/ppp/active',
    '/interface',
    '/ip/address',
    '/ip/dhcp-server/lease',
    '/ip/dhcp-client',
    '/ip/firewall/filter',
    '/ip/route',
    '/ip/service',
    '/queue/simple',
    '/system/resource',
    '/system/identity',
    '/system/clock',
    '/system/package',
    '/log',
  };

  static bool isReadOnlyCommandPath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');
    final base = normalized.endsWith('/print')
        ? normalized.substring(0, normalized.length - '/print'.length)
        : normalized;
    return _readOnlyCommandPaths.contains(base) &&
        (normalized == base || normalized == '$base/print');
  }

  Future<List<Map<String, String>>> runCommand(String path) async {
    final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');
    if (!isReadOnlyCommandPath(normalized)) {
      throw const RouterOsException(
        'الطرفية الحالية للقراءة فقط وتسمح بمسارات فحص محددة. أوامر التغيير أو إعادة التشغيل غير مسموحة.',
        kind: RouterOsErrorKind.forbidden,
      );
    }

    final endpoint = normalized.endsWith('/print')
        ? normalized.substring(0, normalized.length - '/print'.length)
        : normalized;

    if (_rest != null) {
      final data = await _rest!.get(endpoint);
      return _asList(data).map(_toRow).toList();
    }
    if (_binary != null) {
      return _binary!.command('$endpoint/print');
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  Future<void> disconnect() async {
    try {
      _binary?.close();
    } catch (_) {}
    try {
      _rest?.close();
    } catch (_) {}
    _rest = null;
    _binary = null;
    _activeProtocol = null;
    _profile = null;
  }
}
);
    return rate.hasMatch(parts[0]) && rate.hasMatch(parts[1]);
  }

  /// Disconnects one active Hotspot session (does not delete its user).
  Future<void> disconnectHotspotSession(
    String id, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'فصل جلسة Hotspot متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف الجلسة غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.delete('/ip/hotspot/active/$id');
  }

  /// Disconnects a PPP active session by its RouterOS internal id.
  Future<void> disconnectPppoeSession(
    String id, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'فصل جلسة PPP متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف الجلسة غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.delete('/ppp/active/$id');
  }

  /// Changes an interface state on RouterOS v7 after explicit safety approval.
  Future<void> setInterfaceDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تغيير الواجهات متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف الواجهة غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/interface/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Enables/disables an existing firewall filter rule; does not create rules.
  Future<void> setFirewallRuleDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تعديل قواعد الجدار الناري متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف قاعدة الجدار الناري غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/ip/firewall/filter/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Enables/disables a simple queue. Does not rewrite queue limits.
  Future<void> setSimpleQueueDisabled(
    String id,
    bool disabled, {
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    _requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (_rest == null) {
      throw const RouterOsException(
        'تعديل Simple Queue متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف Queue غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/queue/simple/$id', {
      'disabled': disabled ? 'true' : 'false',
    });
  }

  void _requireWriteApproval({
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (!isConnected) {
      throw const RouterOsException('اتصل بالراوتر أولاً.',
          kind: RouterOsErrorKind.network);
    }
  }

  static const Set<String> _readOnlyCommandPaths = {
    '/ip/hotspot/user',
    '/ip/hotspot/active',
    '/ip/hotspot/user/profile',
    '/ppp/secret',
    '/ppp/active',
    '/interface',
    '/ip/address',
    '/ip/dhcp-server/lease',
    '/ip/dhcp-client',
    '/ip/firewall/filter',
    '/ip/route',
    '/ip/service',
    '/queue/simple',
    '/system/resource',
    '/system/identity',
    '/system/clock',
    '/system/package',
    '/log',
  };

  static bool isReadOnlyCommandPath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');
    final base = normalized.endsWith('/print')
        ? normalized.substring(0, normalized.length - '/print'.length)
        : normalized;
    return _readOnlyCommandPaths.contains(base) &&
        (normalized == base || normalized == '$base/print');
  }

  Future<List<Map<String, String>>> runCommand(String path) async {
    final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');
    if (!isReadOnlyCommandPath(normalized)) {
      throw const RouterOsException(
        'الطرفية الحالية للقراءة فقط وتسمح بمسارات فحص محددة. أوامر التغيير أو إعادة التشغيل غير مسموحة.',
        kind: RouterOsErrorKind.forbidden,
      );
    }

    final endpoint = normalized.endsWith('/print')
        ? normalized.substring(0, normalized.length - '/print'.length)
        : normalized;

    if (_rest != null) {
      final data = await _rest!.get(endpoint);
      return _asList(data).map(_toRow).toList();
    }
    if (_binary != null) {
      return _binary!.command('$endpoint/print');
    }
    throw const RouterOsException('اتصل بالراوتر أولاً',
        kind: RouterOsErrorKind.network);
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  Future<void> disconnect() async {
    try {
      _binary?.close();
    } catch (_) {}
    try {
      _rest?.close();
    } catch (_) {}
    _rest = null;
    _binary = null;
    _activeProtocol = null;
    _profile = null;
  }
}
