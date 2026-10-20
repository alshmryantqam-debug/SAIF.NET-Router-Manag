import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'router_client.dart';
import 'routeros_client.dart' show RosException, RosErrorType;

class _ByteReader {
  final Queue<int> _q = Queue<int>();
  Completer<void>? _wait;
  bool closed = false;

  _ByteReader(Socket s) {
    s.listen((d) { _q.addAll(d); _wake(); },
        onDone: () { closed = true; _wake(); },
        onError: (_) { closed = true; _wake(); });
  }

  void _wake() {
    final wait = _wait;
    _wait = null;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  Future<List<int>> bytes(int n) async {
    while (_q.length < n) {
      if (closed) throw const SocketException('انقطع الاتصال بالراوتر');
      _wait = Completer<void>();
      await _wait!.future;
    }
    return List<int>.generate(n, (_) => _q.removeFirst());
  }

  Future<int> byte() async => (await bytes(1))[0];
}

class ApiClient implements RouterOsClient {
  @override
  final String host;
  @override
  final String user;
  @override
  final String pass;
  @override
  final int port;
  @override
  bool get https => false;

  Socket? _sock;
  _ByteReader? _r;
  Future<void> _tail = Future<void>.value();

  ApiClient({required this.host, required this.user, required this.pass, this.port = 8728});

  @override
  String get kind => 'API';

  static const _singletons = {
    '/system/resource', '/system/identity', '/system/clock', '/system/routerboard',
  };

  Future<void> connect() async {
    try {
      _sock = await Socket.connect(host, port, timeout: const Duration(seconds: 6));
    } catch (_) {
      throw RosException(RosErrorType.network, 'تعذر الوصول إلى منفذ API ($port). فعّل خدمة api من IP > Services');
    }
    _r = _ByteReader(_sock!);
    await _run('/login', {'name': user, 'password': pass});
  }

  List<int> _encLen(int l) {
    if (l < 0x80) return [l];
    if (l < 0x4000) { l |= 0x8000; return [(l >> 8) & 0xFF, l & 0xFF]; }
    if (l < 0x200000) { l |= 0xC00000; return [(l >> 16) & 0xFF, (l >> 8) & 0xFF, l & 0xFF]; }
    if (l < 0x10000000) { l |= 0xE0000000; return [(l >> 24) & 0xFF, (l >> 16) & 0xFF, (l >> 8) & 0xFF, l & 0xFF]; }
    return [0xF0, (l >> 24) & 0xFF, (l >> 16) & 0xFF, (l >> 8) & 0xFF, l & 0xFF];
  }

  Future<int> _readLen() async {
    final b = await _r!.byte();
    if ((b & 0x80) == 0) return b;
    if ((b & 0xC0) == 0x80) return ((b & 0x3F) << 8) | await _r!.byte();
    if ((b & 0xE0) == 0xC0) { final x = await _r!.bytes(2); return ((b & 0x1F) << 16) | (x[0] << 8) | x[1]; }
    if ((b & 0xF0) == 0xE0) { final x = await _r!.bytes(3); return ((b & 0x0F) << 24) | (x[0] << 16) | (x[1] << 8) | x[2]; }
    final x = await _r!.bytes(4);
    return (x[0] << 24) | (x[1] << 16) | (x[2] << 8) | x[3];
  }

  void _writeWord(BytesBuilder b, String w) {
    final d = utf8.encode(w);
    b.add(_encLen(d.length));
    b.add(d);
  }

  Future<List<String>> _readSentence() async {
    final words = <String>[];
    while (true) {
      final len = await _readLen();
      if (len == 0) return words;
      words.add(utf8.decode(await _r!.bytes(len), allowMalformed: true));
    }
  }

  Future<List<Map<String, String>>> _run(String cmd, Map<String, String> attrs) async {
    final b = BytesBuilder();
    _writeWord(b, cmd);
    attrs.forEach((k, v) => _writeWord(b, '=$k=$v'));
    b.addByte(0);
    _sock!.add(b.toBytes());
    await _sock!.flush();

    final rows = <Map<String, String>>[];
    String? trap;
    while (true) {
      final s = await _readSentence();
      if (s.isEmpty) continue;
      switch (s.first) {
        case '!re':
          final m = <String, String>{};
          for (final w in s.skip(1)) {
            if (!w.startsWith('=')) continue;
            final i = w.indexOf('=', 1);
            if (i > 0) m[w.substring(1, i)] = w.substring(i + 1);
          }
          rows.add(m);
          break;
        case '!trap':
          trap = s.firstWhere((w) => w.startsWith('=message='), orElse: () => '=message=خطأ من الراوتر').substring(9);
          break;
        case '!fatal':
          throw RosException(RosErrorType.server, s.skip(1).join(' '));
        case '!done':
          if (trap != null) {
            final auth = trap!.contains('invalid user') || trap!.contains('cannot log in') || trap!.contains('not logged in');
            throw RosException(auth ? RosErrorType.auth : RosErrorType.server,
                auth ? 'اسم المستخدم أو كلمة المرور غير صحيحة' : trap!);
          }
          return rows;
      }
    }
  }

  Future<T> _sync<T>(Future<T> Function() f) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try { c.complete(await f()); } catch (e, s) { c.completeError(e, s); }
    });
    return c.future;
  }

  Map<String, String> _attrs(Object? d) => d is Map
      ? {for (final e in d.entries) e.key.toString(): e.value.toString()}
      : <String, String>{};

  String _id(String path) => path.substring(path.lastIndexOf('/') + 1);
  String _parent(String path) => path.substring(0, path.lastIndexOf('/'));

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _sync(() async {
    final normalized = '/${path.replaceFirst(RegExp(r'^/+'), '')}';
    final attrs = <String, String>{};
    query?.forEach((k, v) => attrs[k] = v.toString());
    final rows = await _run('$normalized/print', attrs);
    if (_singletons.contains(normalized)) return rows.isEmpty ? <String, String>{} : rows.first;
    return rows;
  });

  @override
  Future<dynamic> post(String path, [Object? data]) => _sync(() => _run('/${path.replaceFirst(RegExp(r'^/+'), '')}', _attrs(data)));

  @override
  Future<dynamic> put(String path, Object data) => _sync(() async {
    await _run('/${path.replaceFirst(RegExp(r'^/+'), '')}/add', _attrs(data));
    return <String, dynamic>{};
  });

  @override
  Future<dynamic> patch(String path, Object data) => _sync(() async {
    await _run('/${_parent(path)}/set', {'numbers': _id(path), ..._attrs(data)});
    return <String, dynamic>{};
  });

  @override
  Future<dynamic> delete(String path) => _sync(() async {
    await _run('/${_parent(path)}/remove', {'numbers': _id(path)});
    return <String, dynamic>{};
  });

  @override
  Future<List<dynamic>> getPPPoESecrets() async => List<dynamic>.from(await get('ppp/secret') as List);
  @override
  Future<List<dynamic>> getActivePPPoE() async => List<dynamic>.from(await get('ppp/active') as List);
  @override
  Future<List<dynamic>> getHotspotUsers() async => List<dynamic>.from(await get('ip/hotspot/user') as List);
  @override
  Future<List<dynamic>> getInterfaces() async => List<dynamic>.from(await get('interface') as List);
  @override
  Future<List<dynamic>> getIpAddresses() async => List<dynamic>.from(await get('ip/address') as List);
  @override
  Future<List<dynamic>> getQueues() async => List<dynamic>.from(await get('queue/simple') as List);
  @override
  Future<void> createPPPoEUser(String username, String password, String profile) async {
    await put('ppp/secret', {'name': username, 'password': password, 'profile': profile, 'service': 'pppoe'});
  }
  @override
  Future<void> togglePPPoESecret(String id, bool disabled) async {
    await patch('ppp/secret/${Uri.encodeComponent(id)}', {'disabled': disabled ? 'true' : 'false'});
  }
  @override
  Future<void> removePPPoESecret(String id) async { await delete('ppp/secret/${Uri.encodeComponent(id)}'); }
  @override
  Future<void> toggleHotspotUser(String id, bool disabled) async {
    await patch('ip/hotspot/user/${Uri.encodeComponent(id)}', {'disabled': disabled ? 'true' : 'false'});
  }
  @override
  Future<void> createHotspotUser({required String name, required String password, required String profile, String server = 'all', String comment = ''}) async {
    await put('ip/hotspot/user', {'server': server, 'name': name, 'password': password, 'profile': profile, 'comment': comment});
  }
  @override
  Future<void> removeHotspotUser(String id) async { await delete('ip/hotspot/user/${Uri.encodeComponent(id)}'); }

  @override
  Future<bool> runSystemScript(String source) async {
    final scriptName = 'saif_terminal_${DateTime.now().millisecondsSinceEpoch}';
    await put('system/script', {'name': scriptName, 'source': source, 'policy': 'read,write,policy,test'});
    try {
      await post('system/script/run', {'number': scriptName});
      return true;
    } finally {
      final scripts = await get('system/script', query: {'name': scriptName});
      if (scripts is List && scripts.isNotEmpty && scripts.first is Map) {
        final id = scripts.first['.id']?.toString();
        if (id != null) { try { await delete('system/script/${Uri.encodeComponent(id)}'); } catch (_) {} }
      }
    }
  }

  @override
  Future<String> executeRawCommand(String command) async {
    if (command.trim().isEmpty) return 'ERROR: Command is empty.';
    try {
      await runSystemScript(command);
      return 'SUCCESS: RouterOS accepted the script for execution.';
    } on RosException catch (e) {
      return 'ERROR: ${e.status ?? e.type.name} - ${e.message}';
    } catch (e) { return 'ERROR: $e'; }
  }

  @override
  void close() { _sock?.destroy(); }
}
