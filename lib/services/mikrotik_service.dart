import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../models/hotspot_user.dart';
import '../models/pppoe_user.dart';
import '../models/pcc_configuration.dart';
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

  /// Applies guarded RouterOS v7 PCC through a staged, verifiable generation.
  /// Existing PCC rules not created by SAIF.NET are never overwritten.
  /// Executes a guarded PCC deployment through PccFusionEngine.
  Future<String> applyPccLoadBalancing({
    required String lanInterface,
    required List<PccWanConfig> wans,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
    void Function(String message)? onProgress,
  }) {
    return PccFusionEngine(this).execute(
      lanInterface: lanInterface,
      wans: wans,
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
      onProgress: onProgress,
    );
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

  /// Updates selected fields of an existing Hotspot account.
  Future<void> updateHotspotAccount(
    String id, {
    String? password,
    String? profile,
    String? comment,
    String? limitUptime,
    int? limitBytesTotal,
    bool? disabled,
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
        'تعديل حساب Hotspot متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف الحساب غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    final body = <String, dynamic>{};
    if (password != null) body['password'] = password;
    if (profile != null && profile.trim().isNotEmpty) {
      body['profile'] = profile.trim();
    }
    if (comment != null) body['comment'] = comment;
    if (limitUptime != null) body['limit-uptime'] = limitUptime;
    if (limitBytesTotal != null) {
      if (limitBytesTotal < 0) {
        throw const RouterOsException('حد البيانات لا يمكن أن يكون سالباً.',
            kind: RouterOsErrorKind.badRequest);
      }
      body['limit-bytes-total'] = limitBytesTotal.toString();
    }
    if (disabled != null) body['disabled'] = disabled ? 'true' : 'false';
    if (body.isEmpty) {
      throw const RouterOsException('لم يتم تحديد أي تعديل.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/ip/hotspot/user/$id', body);
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

  /// Updates selected fields of an existing PPP secret.
  Future<void> updatePppoeAccount(
    String id, {
    String? password,
    String? profile,
    String? comment,
    String? localAddress,
    String? remoteAddress,
    bool? disabled,
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
        'تعديل حساب PPPoE متاح حالياً عبر REST API في RouterOS v7 فقط.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }
    if (id.trim().isEmpty) {
      throw const RouterOsException('معرّف حساب PPP غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    final body = <String, dynamic>{};
    if (password != null) body['password'] = password;
    if (profile != null && profile.trim().isNotEmpty) {
      body['profile'] = profile.trim();
    }
    if (comment != null) body['comment'] = comment;
    if (localAddress != null) body['local-address'] = localAddress;
    if (remoteAddress != null) body['remote-address'] = remoteAddress;
    if (disabled != null) body['disabled'] = disabled ? 'true' : 'false';
    if (body.isEmpty) {
      throw const RouterOsException('لم يتم تحديد أي تعديل.',
          kind: RouterOsErrorKind.badRequest);
    }
    await _rest!.patch('/ppp/secret/$id', body);
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
    final rate = RegExp(r'^(?:0|[1-9][0-9]*)(?:[kKmMgG])?$');
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
    '/interface/wireless/registration-table',
    '/interface/wifi/registration-table',
    '/ip/neighbor',
    '/ip/firewall/filter',
    '/ip/route',
    '/ip/service',
    '/queue/simple',
    '/system/resource',
    '/system/health',
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

/// Transactional RouterOS v7 PCC deployment engine. All writes use the
/// authenticated session held by MikrotikService; this class never creates
/// a second client or stores credentials.
class PccFusionEngine {
  PccFusionEngine(this._service);

  final MikrotikService _service;

  Future<String> execute({
    required String lanInterface,
    required List<PccWanConfig> wans,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
    void Function(String message)? onProgress,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    if (!_service.isConnected) {
      throw const RouterOsException(
        'اتصل بالراوتر أولاً قبل تطبيق PCC.',
        kind: RouterOsErrorKind.network,
      );
    }
    if (_service._rest == null || _service._activeProtocol != ApiProtocol.rest) {
      throw const RouterOsException(
        'تطبيق PCC الآمن متاح عبر REST API في RouterOS v7 فقط. لم يتم تغيير أي إعداد.',
        kind: RouterOsErrorKind.methodNotAllowed,
      );
    }

    final namePattern = RegExp(r'^[a-zA-Z0-9_.-]{1,64}$');
    final lan = lanInterface.trim();
    if (!namePattern.hasMatch(lan)) {
      throw const RouterOsException(
        'اسم واجهة LAN غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    if (wans.length < 2 || wans.length > 4) {
      throw const RouterOsException(
        'يجب تحديد خطّي WAN على الأقل، وبحد أقصى أربعة خطوط.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    if (wans.any((wan) =>
        !namePattern.hasMatch(wan.interfaceName.trim()) ||
        wan.weight < 1 ||
        wan.weight > 10 ||
        wan.weight.roundToDouble() != wan.weight)) {
      throw const RouterOsException(
        'تحقق من أسماء واجهات WAN وأوزانها؛ الوزن من 1 إلى 10.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    final names = wans.map((wan) => wan.interfaceName.trim()).toSet();
    if (names.length != wans.length || names.contains(lan)) {
      throw const RouterOsException(
        'يجب أن تكون واجهات WAN فريدة ومختلفة عن واجهة LAN.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    for (final wan in wans) {
      final gateway = InternetAddress.tryParse(wan.gateway.trim());
      if (gateway == null || gateway.type != InternetAddressType.IPv4) {
        throw RouterOsException(
          'بوابة WAN ' + wan.interfaceName +
              ' غير صالحة. أدخل عنوان IPv4 مثل 192.168.1.1.',
          kind: RouterOsErrorKind.badRequest,
        );
      }
    }

    onProgress?.call('جارٍ فحص واجهات LAN وWAN والبوابات...');
    final interfaceRows = await _service.interfaces();
    final byName = <String, InterfaceInfo>{
      for (final item in interfaceRows) item.name: item,
    };
    final lanInfo = byName[lan];
    if (lanInfo == null || lanInfo.disabled) {
      throw RouterOsException(
        'واجهة LAN "' + lan + '" غير موجودة أو معطلة.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    for (final wan in wans) {
      final name = wan.interfaceName.trim();
      final info = byName[name];
      if (info == null || info.disabled || !info.running) {
        throw RouterOsException(
          'واجهة WAN "' + name +
              '" غير موجودة أو معطلة أو لا تحمل رابطاً عاملاً.',
          kind: RouterOsErrorKind.badRequest,
        );
      }
    }

    bool isDisabled(Map<String, dynamic> row) {
      final value = (row['disabled'] ?? 'false').toString().toLowerCase();
      return value == 'true' || value == 'yes';
    }

    bool isOwnedComment(Object? value) {
      final comment = (value ?? '').toString();
      return comment.startsWith('SAIFNET-PCC-') ||
          comment == 'Nova_PCC' ||
          comment.startsWith('Nova_PCC:');
    }

    onProgress?.call('جارٍ فحص تعارض قواعد PCC الحالية...');
    final mangleRows = _asList(await _service._rest!.get('/ip/firewall/mangle'));
    final unmanagedPcc = mangleRows.where((row) {
      final classifier =
          (row['per-connection-classifier'] ?? '').toString().trim();
      final comment = (row['comment'] ?? '').toString();
      final chain = (row['chain'] ?? '').toString();
      final input = (row['in-interface'] ?? '').toString();
      final competesWithLan = chain == 'prerouting' &&
          (input.isEmpty || input == lan);
      final competesWithOutput = chain == 'output';
      return classifier.isNotEmpty &&
          !isDisabled(row) &&
          !isOwnedComment(comment) &&
          (competesWithLan || competesWithOutput);
    }).toList();
    if (unmanagedPcc.isNotEmpty) {
      throw const RouterOsException(
        'اكتُشفت قواعد PCC فعّالة لا يديرها SAIF.NET. عالج التعارض بعد النسخ الاحتياطي؛ لم يجر أي تغيير.',
        kind: RouterOsErrorKind.badRequest,
      );
    }

    final generation =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final tag = 'SAIFNET-PCC-' + generation;
    final totalWeight =
        wans.fold<int>(0, (sum, wan) => sum + wan.weight.round());
    final tableNames = <String>[];
    final markNames = <String>[];
    for (var wanIndex = 0; wanIndex < wans.length; wanIndex++) {
      final wan = wans[wanIndex];
      final compact = wan.interfaceName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final shortName = compact.isEmpty
          ? 'wan'
          : (compact.length > 6 ? compact.substring(0, 6) : compact);
      // The index keeps table/mark names unique even for similar names,
      // e.g. starlink-east and starlink-west.
      final uniqueSuffix = '_' + wanIndex.toString() + '_' + generation;
      tableNames.add('sfpc_' + shortName + uniqueSuffix);
      markNames.add('sfpc_' + shortName + uniqueSuffix + '_c');
    }

    final created = <Map<String, String>>[];
    final createdTables = <Map<String, String>>[];
    final stagedRoutes = <Map<String, String>>[];
    final stagedNat = <Map<String, String>>[];
    final stagedConnections = <Map<String, String>>[];
    final stagedRouting = <Map<String, String>>[];
    final oldOwned = <Map<String, String>>[];
    final oldActive = <Map<String, String>>[];
    final oldTableCandidates = <Map<String, String>>[];

    Future<Map<String, String>> addItem(
      String path,
      Map<String, dynamic> body,
    ) async {
      final response = await _service._rest!.put(path, body);
      final id = (_service._extractMap(response)['.id'] ?? '').toString();
      if (id.isEmpty) {
        throw RouterOsException(
          'لم يُرجع الراوتر معرّف العنصر الجديد في ' + path + '.',
          kind: RouterOsErrorKind.protocol,
        );
      }
      final item = <String, String>{'path': path, 'id': id};
      created.add(item);
      return item;
    }

    Future<void> rollback() async {
      for (final item in created.reversed) {
        try {
          await _service._rest!.delete(item['path']! + '/' + item['id']!);
        } catch (_) {}
      }
      for (final item in createdTables.reversed) {
        try {
          await _service._rest!.delete('/routing/table/' + item['id']!);
        } catch (_) {}
      }
      for (final item in oldActive) {
        try {
          await _service._rest!.patch(
            item['path']! + '/' + item['id']!,
            <String, dynamic>{'disabled': 'false'},
          );
        } catch (_) {}
      }
    }

    final oldMangle = mangleRows
        .where((row) => isOwnedComment(row['comment']))
        .toList();
    final oldNat = _asList(await _service._rest!.get('/ip/firewall/nat'))
        .where((row) => isOwnedComment(row['comment']))
        .toList();
    onProgress?.call('جارٍ فحص المسارات الحالية وتحديد أولوية Failover الآمنة...');
    final routeRows = _asList(await _service._rest!.get('/ip/route'));
    final oldRoutes = routeRows
        .where((row) => isOwnedComment(row['comment']))
        .toList();
    final unmanagedMainDefaults = routeRows.where((row) {
      final destination = (row['dst-address'] ?? '').toString();
      final table = (row['routing-table'] ?? '').toString();
      final comment = (row['comment'] ?? '').toString();
      return destination == '0.0.0.0/0' &&
          (table.isEmpty || table == 'main') &&
          !isOwnedComment(comment) &&
          !isDisabled(row);
    });
    final mainDefaultBaseDistance = unmanagedMainDefaults.fold<int>(
      0,
      (highest, row) {
        final distance = int.tryParse((row['distance'] ?? '1').toString()) ?? 1;
        return distance > highest ? distance : highest;
      },
    );
    if (mainDefaultBaseDistance + wans.length > 255) {
      throw const RouterOsException(
        'لا يمكن إضافة مسارات الطوارئ بأمان لأن مسافات المسارات الافتراضية الحالية وصلت إلى الحد الأقصى 255. لم يتم تغيير أي إعداد.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    for (final group in <MapEntry<String, List<Map<String, dynamic>>>>[
      MapEntry('/ip/firewall/mangle', oldMangle),
      MapEntry('/ip/firewall/nat', oldNat),
      MapEntry('/ip/route', oldRoutes),
    ]) {
      for (final row in group.value) {
        final id = (row['.id'] ?? '').toString();
        if (id.isEmpty) continue;
        final active = !isDisabled(row);
        final item = <String, String>{
          'path': group.key,
          'id': id,
          'wasActive': active.toString(),
        };
        oldOwned.add(item);
        if (active) oldActive.add(item);
      }
    }

    final oldGenerations = <String>{};
    for (final row in <Map<String, dynamic>>[
      ...oldMangle,
      ...oldNat,
      ...oldRoutes,
    ]) {
      final comment = (row['comment'] ?? '').toString();
      const prefix = 'SAIFNET-PCC-';
      if (comment.startsWith(prefix)) {
        final remaining = comment.substring(prefix.length);
        final split = remaining.indexOf(':');
        if (split > 0) oldGenerations.add(remaining.substring(0, split));
      }
    }
    final priorTables = _asList(await _service._rest!.get('/routing/table'));
    final legacyTableNames = oldRoutes
        .map((row) => (row['routing-table'] ?? '').toString())
        .where((name) => name.isNotEmpty && name != 'main')
        .toSet();
    for (final row in priorTables) {
      final name = (row['name'] ?? '').toString();
      final id = (row['.id'] ?? '').toString();
      if (id.isNotEmpty &&
          (oldGenerations.any((old) => name.endsWith('_' + old)) ||
              legacyTableNames.contains(name))) {
        oldTableCandidates.add(<String, String>{'name': name, 'id': id});
      }
    }

    try {
      onProgress?.call('جارٍ إنشاء جداول التوجيه الجديدة بوضع التعطيل الآمن...');
      // Stage all new resources disabled so no incomplete generation routes traffic.
      for (final name in tableNames) {
        final response = await _service._rest!.put('/routing/table', <String, dynamic>{
          'name': name,
          'fib': 'yes',
        });
        final id = (_service._extractMap(response)['.id'] ?? '').toString();
        if (id.isEmpty) {
          throw const RouterOsException(
            'لم يُرجع الراوتر معرّف جدول التوجيه.',
            kind: RouterOsErrorKind.protocol,
          );
        }
        createdTables.add(<String, String>{'name': name, 'id': id});
      }

      onProgress?.call('جارٍ بناء مسارات PCC ومسارات الطوارئ لكل WAN...');
      for (var tableIndex = 0; tableIndex < wans.length; tableIndex++) {
        for (var offset = 0; offset < wans.length; offset++) {
          final gatewayIndex = (tableIndex + offset) % wans.length;
          stagedRoutes.add(await addItem('/ip/route', <String, dynamic>{
            'dst-address': '0.0.0.0/0',
            'gateway': wans[gatewayIndex].gateway.trim() + '%' +
                wans[gatewayIndex].interfaceName.trim(),
            'routing-table': tableNames[tableIndex],
            'check-gateway': 'ping',
            'distance': (offset + 1).toString(),
            'disabled': 'true',
            'comment': tag +
                ':route:policy:' +
                tableIndex.toString() +
                ':' +
                gatewayIndex.toString(),
          }));
        }
      }

      // Keep any pre-existing, unmanaged main defaults in front. These
      // generated routes become the main-table fallback tier rather than
      // silently replacing the router's current default route.
      for (var index = 0; index < wans.length; index++) {
        stagedRoutes.add(await addItem('/ip/route', <String, dynamic>{
          'dst-address': '0.0.0.0/0',
          'gateway': wans[index].gateway.trim() + '%' +
              wans[index].interfaceName.trim(),
          'check-gateway': 'ping',
          'distance': (mainDefaultBaseDistance + index + 1).toString(),
          'disabled': 'true',
          'comment': tag + ':failover:main:' + index.toString(),
        }));
      }

      onProgress?.call('جارٍ حفظ مسار الاتصالات الواردة وتوزيع الأوزان...');
      for (var index = 0; index < wans.length; index++) {
        stagedConnections.add(await addItem(
          '/ip/firewall/mangle',
          <String, dynamic>{
            'chain': 'prerouting',
            'action': 'mark-connection',
            'in-interface': wans[index].interfaceName.trim(),
            'connection-state': 'new',
            'connection-mark': 'no-mark',
            'new-connection-mark': markNames[index],
            'passthrough': 'yes',
            'disabled': 'true',
            'comment': tag + ':mangle:inbound:' + index.toString(),
          },
        ));
      }

      var bucket = 0;
      for (var wanIndex = 0; wanIndex < wans.length; wanIndex++) {
        for (var repeat = 0;
            repeat < wans[wanIndex].weight.round();
            repeat++) {
          stagedConnections.add(await addItem(
            '/ip/firewall/mangle',
            <String, dynamic>{
              'chain': 'prerouting',
              'action': 'mark-connection',
              'in-interface': lan,
              'connection-state': 'new',
              'connection-mark': 'no-mark',
              'dst-address-type': '!local',
              'per-connection-classifier':
                  'both-addresses-and-ports:' +
                      totalWeight.toString() +
                      '/' +
                      bucket.toString(),
              'new-connection-mark': markNames[wanIndex],
              'passthrough': 'yes',
              'disabled': 'true',
              'comment': tag + ':mangle:conn:lan:' + bucket.toString(),
            },
          ));
          stagedConnections.add(await addItem(
            '/ip/firewall/mangle',
            <String, dynamic>{
              'chain': 'output',
              'action': 'mark-connection',
              'connection-state': 'new',
              'connection-mark': 'no-mark',
              'dst-address-type': '!local',
              'per-connection-classifier':
                  'both-addresses-and-ports:' +
                      totalWeight.toString() +
                      '/' +
                      bucket.toString(),
              'new-connection-mark': markNames[wanIndex],
              'passthrough': 'yes',
              'disabled': 'true',
              'comment': tag + ':mangle:conn:output:' + bucket.toString(),
            },
          ));
          bucket++;
        }
      }

      for (var index = 0; index < wans.length; index++) {
        stagedRouting.add(await addItem(
          '/ip/firewall/mangle',
          <String, dynamic>{
            'chain': 'prerouting',
            'action': 'mark-routing',
            'in-interface': lan,
            'connection-mark': markNames[index],
            'new-routing-mark': tableNames[index],
            'passthrough': 'no',
            'disabled': 'true',
            'comment': tag + ':mangle:route:prerouting:' + index.toString(),
          },
        ));
        stagedRouting.add(await addItem(
          '/ip/firewall/mangle',
          <String, dynamic>{
            'chain': 'output',
            'action': 'mark-routing',
            'connection-mark': markNames[index],
            'new-routing-mark': tableNames[index],
            'passthrough': 'no',
            'disabled': 'true',
            'comment': tag + ':mangle:route:output:' + index.toString(),
          },
        ));
      }

      for (var index = 0; index < wans.length; index++) {
        stagedNat.add(await addItem('/ip/firewall/nat', <String, dynamic>{
          'chain': 'srcnat',
          'action': 'masquerade',
          'out-interface': wans[index].interfaceName.trim(),
          'disabled': 'true',
          'comment': tag + ':nat:' + index.toString(),
        }));
      }

      onProgress?.call('جارٍ إيقاف قواعد SAIF.NET السابقة مؤقتاً لحفظ إمكانية التراجع...');
      // Briefly park only the prior SAIF.NET-owned rules and keep their IDs
      // so a failed activation can restore the previous active generation.
      for (final item in oldActive) {
        await _service._rest!.patch(
          item['path']! + '/' + item['id']!,
          <String, dynamic>{'disabled': 'true'},
        );
      }

      Future<void> enableAll(List<Map<String, String>> items) async {
        for (final item in items) {
          await _service._rest!.patch(
            item['path']! + '/' + item['id']!,
            <String, dynamic>{'disabled': 'false'},
          );
        }
      }

      onProgress?.call('جارٍ تفعيل PCC وNAT ومسارات Failover...');
      await enableAll(stagedRoutes);
      await enableAll(stagedNat);
      await enableAll(stagedConnections);
      await enableAll(stagedRouting);

      onProgress?.call('جارٍ التحقق من جميع القواعد والمسارات بعد التفعيل...');
      final actualMangle = _asList(await _service._rest!.get('/ip/firewall/mangle'))
          .where((row) => (row['comment'] ?? '').toString().startsWith(tag))
          .toList();
      final actualNat = _asList(await _service._rest!.get('/ip/firewall/nat'))
          .where((row) => (row['comment'] ?? '').toString().startsWith(tag))
          .toList();
      final actualRoutes = _asList(await _service._rest!.get('/ip/route'))
          .where((row) => (row['comment'] ?? '').toString().startsWith(tag))
          .toList();
      final expectedMangleCount = (totalWeight * 2) + (wans.length * 3);
      final expectedRouteCount = (wans.length * wans.length) + wans.length;
      if (actualMangle.length != expectedMangleCount ||
          actualNat.length != wans.length ||
          actualRoutes.length != expectedRouteCount ||
          actualMangle.any(isDisabled) ||
          actualNat.any(isDisabled) ||
          actualRoutes.any(isDisabled)) {
        throw const RouterOsException(
          'فشل التحقق من قواعد PCC الجديدة؛ تمت محاولة استعادة الجيل السابق.',
          kind: RouterOsErrorKind.server,
        );
      }
    } catch (_) {
      await rollback();
      rethrow;
    }

    // A verified generation is live. Remove only records carrying our marker.
    for (final item in oldOwned) {
      try {
        await _service._rest!.delete(item['path']! + '/' + item['id']!);
      } catch (_) {}
    }
    try {
      final routesNow = _asList(await _service._rest!.get('/ip/route'));
      final mangleNow = _asList(await _service._rest!.get('/ip/firewall/mangle'));
      final rulesNow = _asList(await _service._rest!.get('/routing/rule'));
      for (final table in oldTableCandidates) {
        final name = table['name']!;
        final referencedByRoute = routesNow.any(
          (row) => (row['routing-table'] ?? '').toString() == name,
        );
        final referencedByMangle = mangleNow.any(
          (row) => (row['new-routing-mark'] ?? '').toString() == name,
        );
        final referencedByRule = rulesNow.any(
          (row) => (row['table'] ?? '').toString() == name,
        );
        if (!referencedByRoute && !referencedByMangle && !referencedByRule) {
          try {
            await _service._rest!.delete('/routing/table/' + table['id']!);
          } catch (_) {}
        }
      }
    } catch (_) {
      // The new generation is verified; optional stale-table cleanup is best-effort.
    }

    onProgress?.call('اكتمل فحص الجيل الجديد وتنظيف القواعد القديمة التي يديرها SAIF.NET فقط.');
    return 'تم تطبيق PCC الموزون والتحقق منه على ' +
        wans.length.toString() +
        ' خطوط. مجموع الأوزان ' +
        totalWeight.toString() +
        '. أُنشئت مسارات بديلة داخل كل جدول، ومسارات main احتياطية بعد المسارات الافتراضية الموجودة. فحص الانقطاع يعتمد على ping إلى بوابة الخط، وليس فحصاً مستقلاً لنهاية الإنترنت.';
  }


  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return <Map<String, dynamic>>[];
  }
  /// Reads an allowlisted RouterOS v7 REST menu. No demo data is returned.
  Future<List<Map<String, dynamic>>> readMenu(String path) async {
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'لا يوجد اتصال REST فعّال. اتصل براوتر RouterOS v7 أولاً.',
        kind: RouterOsErrorKind.network,
      );
    }
    const allowedReadMenus = <String>{
      '/system/resource', '/system/health', '/system/identity',
      '/system/routerboard', '/system/log', '/interface',
      '/interface/ethernet', '/ip/address', '/ip/route',
      '/ip/dhcp-server/lease', '/ip/arp', '/ip/firewall/filter',
      '/ip/firewall/nat', '/ip/firewall/mangle',
      '/ip/firewall/address-list', '/ip/firewall/connection',
      '/queue/simple', '/queue/tree', '/ppp/secret', '/ppp/active',
      '/ppp/profile', '/ip/hotspot/user', '/ip/hotspot/active',
      '/ip/hotspot/host', '/ip/hotspot/profile',
      '/ip/hotspot/user/profile', '/ip/dns', '/ip/pool',
      '/ip/dhcp-server', '/system/scheduler', '/system/script',
      '/routing/table', '/routing/rule',
    };
    if (!allowedReadMenus.contains(path)) {
      throw RouterOsException(
        'مسار القراءة غير مسموح به من خلال هذه الواجهة: $path',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    final response = await api.get(path);
    return _asList(response);
  }

  /// Runs the actual RouterOS ping tool via REST.
  Future<List<Map<String, dynamic>>> pingHost(
    String address, {
    int count = 4,
    int intervalMs = 500,
  }) async {
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'يتطلب Ping اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final target = address.trim();
    if (target.isEmpty || target.length > 253 ||
        RegExp(r'[\s;|\x00-\x1f]').hasMatch(target)) {
      throw const RouterOsException('عنوان الهدف غير صالح.',
          kind: RouterOsErrorKind.badRequest);
    }
    if (count < 1 || count > 10 || intervalMs < 100 || intervalMs > 5000) {
      throw const RouterOsException(
        'عدد المحاولات أو الفاصل الزمني خارج الحدود المسموحة.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    final response = await api.post('/ping', <String, dynamic>{
      'address': target,
      'count': count.toString(),
      'interval': '${intervalMs}ms',
    });
    return _asList(response);
  }

  /// Creates a non-sensitive RouterOS text export, reads it in bounded chunks,
  /// and attempts to remove the temporary router-side file in all cases.
  /// This does not include passwords/private keys and is only available on REST v7.
  Future<String> exportConfigurationText() async {
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'تصدير الإعدادات يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }

    final fileBase = 'nova-export-${DateTime.now().millisecondsSinceEpoch}';
    final fileName = '$fileBase.rsc';
    var exportRequested = false;
    try {
      await api.post('/export', <String, dynamic>{'file': fileBase});
      exportRequested = true;

      final output = StringBuffer();
      var offset = 0;
      const chunkSize = 32768;
      // Safety cap: refuse to pull unexpectedly large configuration dumps.
      const maxBytes = 8 * 1024 * 1024;
      while (offset < maxBytes) {
        final response = await api.post('/file/read', <String, dynamic>{
          'file': fileName,
          'chunk-size': chunkSize.toString(),
          'offset': offset.toString(),
        });
        final rows = _asList(response);
        if (rows.isEmpty) break;
        final data = rows.first['data']?.toString() ?? '';
        if (data.isEmpty) break;
        output.write(data);
        final bytes = utf8.encode(data).length;
        offset += bytes;
        if (data.length < chunkSize) break;
      }
      final result = output.toString();
      if (result.trim().isEmpty) {
        throw const RouterOsException(
          'عاد التصدير فارغاً؛ لم يتم اعتماد النسخة.',
          kind: RouterOsErrorKind.protocol,
        );
      }
      if (result.length >= maxBytes) {
        throw const RouterOsException(
          'تجاوز ملف التصدير الحد الآمن (8 MiB)، أوقفنا القراءة.',
          kind: RouterOsErrorKind.badRequest,
        );
      }
      return result;
    } finally {
      if (exportRequested) {
        try {
          await api.delete('/file/$fileName');
        } catch (_) {
          // Do not hide the primary export/read failure; caller should warn that
          // router-side cleanup may need manual review if delete failed.
        }
      }
    }
  }

  /// Narrow, explicit mutation. UI must confirm and attest backup/rollback.
  Future<void> setObjectDisabled({
    required String menu,
    required String id,
    required bool disabled,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'تعديل الإعدادات يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    const mutableMenus = <String>{
      '/interface', '/queue/simple', '/queue/tree', '/ppp/secret',
      '/ip/hotspot/user', '/ip/firewall/filter', '/ip/firewall/nat',
      '/ip/firewall/mangle', '/ip/firewall/address-list',
      '/ip/dhcp-server/lease',
    };
    if (!mutableMenus.contains(menu) || id.isEmpty ||
        !RegExp(r'^\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
).hasMatch(id)) {
      throw const RouterOsException(
        'المورد أو معرّف RouterOS غير صالح لهذه العملية.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.patch('$menu/$id', <String, dynamic>{
      'disabled': disabled ? 'true' : 'false',
    });
  }

  /// Disconnects one active PPP/Hotspot session with explicit confirmation.
  Future<void> disconnectActiveSession({
    required String kind,
    required String id,
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    RouterOperationGuard.requireWriteApproval(
      explicitlyConfirmed: explicitlyConfirmed,
      backupVerified: backupVerified,
      rollbackPlanAvailable: rollbackPlanAvailable,
    );
    final api = _rest;
    if (api == null) {
      throw const RouterOsException(
        'إنهاء الجلسة يتطلب اتصال REST فعالاً مع RouterOS v7.',
        kind: RouterOsErrorKind.network,
      );
    }
    final menu = switch (kind) {
      'ppp' => '/ppp/active',
      'hotspot' => '/ip/hotspot/active',
      _ => '',
    };
    if (menu.isEmpty || id.isEmpty ||
        !RegExp(r'^\\*[0-9A-Fa-f]+$').hasMatch(id)) {
      throw const RouterOsException(
        'نوع الجلسة أو معرّفها غير صالح.',
        kind: RouterOsErrorKind.badRequest,
      );
    }
    await api.delete('$menu/$id');
  }


}
