/// RouterOS v6/v7 Binary API Client
/// 
/// This is a REAL implementation of the MikroTik Binary API protocol:
/// - Length-prefixed sentence encoding
/// - Tag-based request/response matching
/// - Modern login (RouterOS 6.43+)
/// - Legacy MD5 challenge/response (RouterOS < 6.43)
///
/// Note: For v7, prefer REST API. This is required for v6.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class RouterOsBinaryApi {
  Socket? _socket;
  final List<int> _buffer = [];
  final Map<String, Completer<List<Map<String, String>>>> _pending = {};
  final Map<String, List<Map<String, String>>> _responses = {};
  int _tagCounter = 1;
  bool _connected = false;

  bool get isConnected => _connected;

  // ═══════════════════════════════════════════════
  //  CONNECT
  // ═══════════════════════════════════════════════
  Future<void> connect({
    required String host,
    required int port,
    bool useSsl = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (useSsl) {
      _socket = await SecureSocket.connect(
        host, port,
        timeout: timeout,
      );
    } else {
      _socket = await Socket.connect(host, port, timeout: timeout);
    }
    _connected = true;
    _socket!.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  // ═══════════════════════════════════════════════
  //  LOGIN
  // ═══════════════════════════════════════════════
  Future<bool> login(String username, String password) async {
    // 1) Modern login (RouterOS 6.43+)
    try {
      final modern = await send([
        '/login',
        '=name=$username',
        '=password=$password',
      ], timeout: const Duration(seconds: 8));

      final done = modern.any((s) => s['!type'] == '!done' && !s.containsKey('ret'));
      final trap = modern.any((s) => s['!type'] == '!trap');

      if (done && !trap) return true;
    } catch (_) {}

    // 2) Legacy login (MD5 challenge/response)
    try {
      final challengeRes = await send(
        ['/login'],
        timeout: const Duration(seconds: 8),
      );

      final doneMsg = challengeRes.firstWhere(
        (s) => s['!type'] == '!done',
        orElse: () => const {},
      );

      final challengeHex = doneMsg['ret'];
      if (challengeHex == null || challengeHex.isEmpty) return false;

      final challengeBytes = _hexToBytes(challengeHex);
      final md5Input = <int>[
        0x00,
        ...utf8.encode(password),
        ...challengeBytes,
      ];
      final digest = md5.convert(md5Input).bytes;
      final responseHex =
          digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final loginRes = await send([
        '/login',
        '=name=$username',
        '=response=00$responseHex',
      ], timeout: const Duration(seconds: 8));

      final success = loginRes.any((s) => s['!type'] == '!done' &&
          !s.containsKey('ret') &&
          !s.containsKey('message'));
      final failed = loginRes.any((s) => s['!type'] == '!trap');

      return success && !failed;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  //  SEND COMMAND
  // ═══════════════════════════════════════════════
  Future<List<Map<String, String>>> send(
    List<String> words, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!_connected || _socket == null) {
      throw StateError('غير متصل بالراوتر');
    }

    final tag = (_tagCounter++).toString();
    final completer = Completer<List<Map<String, String>>>();
    _pending[tag] = completer;
    _responses[tag] = <Map<String, String>>[];

    _socket!.add(_encodeSentence([...words, '.tag=$tag']));
    await _socket!.flush();

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(tag);
        _responses.remove(tag);
        throw TimeoutException('انتهت مهلة الأمر');
      },
    );
  }

  // ═══════════════════════════════════════════════
  //  ENCODE
  // ═══════════════════════════════════════════════
  Uint8List _encodeSentence(List<String> words) {
    final builder = BytesBuilder();
    for (final w in words) {
      final bytes = utf8.encode(w);
      builder.add(_encodeLength(bytes.length));
      builder.add(bytes);
    }
    builder.addByte(0);
    return builder.toBytes();
  }

  Uint8List _encodeLength(int len) {
    if (len < 0x80) return Uint8List.fromList([len]);
    if (len < 0x4000) return Uint8List.fromList([(len >> 8) | 0x80, len & 0xFF]);
    if (len < 0x200000) {
      return Uint8List.fromList([(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF]);
    }
    if (len < 0x10000000) {
      return Uint8List.fromList([
        (len >> 24) | 0xE0,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
      ]);
    }
    return Uint8List.fromList([
      0xF0,
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
    ]);
  }

  // ═══════════════════════════════════════════════
  //  DECODE
  // ═══════════════════════════════════════════════
  void _onData(Uint8List data) {
    _buffer.addAll(data);
    _drain();
  }

  void _onError(Object e) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(e);
    }
    _pending.clear();
    _responses.clear();
    _connected = false;
  }

  void _onDone() {
    _connected = false;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('انقطع الاتصال بالراوتر'));
      }
    }
    _pending.clear();
    _responses.clear();
  }

  void _drain() {
    while (true) {
      final sentence = _tryReadSentence();
      if (sentence == null) return;
      if (sentence.isEmpty) continue;

      String? tag;
      for (final m in sentence) {
        if (m.containsKey('tag') || m.containsKey('.tag')) {
          tag = m['tag'] ?? m['.tag'];
          break;
        }
      }
      if (tag == null) continue;

      final completer = _pending[tag];
      if (completer == null) continue;

      final isTerminal = sentence.any(
        (m) =>
            m['!type'] == '!done' ||
            m['!type'] == '!trap' ||
            m['!type'] == '!fatal',
      );

      if (isTerminal) {
        _pending.remove(tag);
        final response = _responses.remove(tag) ?? <Map<String, String>>[];
        response.addAll(sentence);
        completer.complete(response);
      } else {
        _responses.putIfAbsent(tag, () => <Map<String, String>>[]).addAll(sentence);
      }
    }
  }

  List<Map<String, String>>? _tryReadSentence() {
    final words = <String>[];
    var offset = 0;

    while (offset < _buffer.length) {
      final lenResult = _readLength(offset);
      if (lenResult == null) return null;
      offset += lenResult.$2;

      if (lenResult.$1 == 0) {
        _buffer.removeRange(0, offset);
        return _parseWords(words);
      }

      if (offset + lenResult.$1 > _buffer.length) return null;

      final bytes = _buffer.sublist(offset, offset + lenResult.$1);
      words.add(utf8.decode(bytes, allowMalformed: true));
      offset += lenResult.$1;
    }
    return null;
  }

  (int, int)? _readLength(int offset) {
    if (offset >= _buffer.length) return null;
    final b0 = _buffer[offset];

    if (b0 < 0x80) return (b0, 1);
    if (b0 < 0xC0) {
      if (offset + 2 > _buffer.length) return null;
      return (((b0 & 0x3F) << 8) | _buffer[offset + 1], 2);
    }
    if (b0 < 0xE0) {
      if (offset + 3 > _buffer.length) return null;
      return (
        ((b0 & 0x1F) << 16) |
            (_buffer[offset + 1] << 8) |
            _buffer[offset + 2],
        3
      );
    }
    if (b0 < 0xF0) {
      if (offset + 4 > _buffer.length) return null;
      return (
        ((b0 & 0x0F) << 24) |
            (_buffer[offset + 1] << 16) |
            (_buffer[offset + 2] << 8) |
            _buffer[offset + 3],
        4
      );
    }
    if (offset + 5 > _buffer.length) return null;
    return (
      (_buffer[offset + 1] << 24) |
          (_buffer[offset + 2] << 16) |
          (_buffer[offset + 3] << 8) |
          _buffer[offset + 4],
      5
    );
  }

  List<Map<String, String>> _parseWords(List<String> words) {
    final results = <Map<String, String>>[];
    var current = <String, String>{};

    for (final w in words) {
      if (w.startsWith('!')) {
        if (current.isNotEmpty) results.add(current);
        current = {'!type': w};
      } else if (w.startsWith('=')) {
        final eq = w.indexOf('=', 1);
        if (eq > 0) current[w.substring(1, eq)] = w.substring(eq + 1);
      } else if (w.startsWith('.')) {
        final eq = w.indexOf('=');
        if (eq > 0) current[w.substring(1, eq)] = w.substring(eq + 1);
      }
    }
    if (current.isNotEmpty) results.add(current);
    return results;
  }

  List<int> _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = <int>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      out.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  // ═══════════════════════════════════════════════
  //  HIGH-LEVEL COMMANDS
  // ═══════════════════════════════════════════════
  Future<Map<String, String>> getResource() async {
    final res = await send(['/system/resource/print']);
    return res.firstWhere(
      (m) => m['!type'] == '!re',
      orElse: () => const {},
    );
  }

  Future<Map<String, String>> getIdentity() async {
    final res = await send(['/system/identity/print']);
    return res.firstWhere(
      (m) => m['!type'] == '!re',
      orElse: () => const {},
    );
  }

  Future<List<Map<String, String>>> getHotspotUsers() async {
    final res = await send(['/ip/hotspot/user/print']);
    return res.where((m) => m['!type'] == '!re').toList();
  }

  Future<List<Map<String, String>>> getList(String command) async {
    if (!command.startsWith('/') || !command.endsWith('/print')) {
      throw ArgumentError.value(command, 'command', 'Only explicit read-only /print commands are allowed.');
    }
    final res = await send([command]);
    final trap = res.where((m) => m['!type'] == '!trap').toList();
    if (trap.isNotEmpty) {
      throw Exception(trap.map((m) => m['message'] ?? 'RouterOS API error').join('; '));
    }
    return res.where((m) => m['!type'] == '!re').toList();
  }

  Future<List<Map<String, String>>> interfaces() => getList('/interface/print');
  Future<List<Map<String, String>>> hotspotActive() => getList('/ip/hotspot/active/print');
  Future<List<Map<String, String>>> pppUsers() => getList('/ppp/secret/print');
  Future<List<Map<String, String>>> pppActive() => getList('/ppp/active/print');
  Future<List<Map<String, String>>> dhcpLeases() => getList('/ip/dhcp-server/lease/print');
  Future<List<Map<String, String>>> simpleQueues() => getList('/queue/simple/print');
  Future<List<Map<String, String>>> ipAddresses() => getList('/ip/address/print');
  Future<List<Map<String, String>>> firewallFilterRules() => getList('/ip/firewall/filter/print');
  Future<List<Map<String, String>>> firewallNatRules() => getList('/ip/firewall/nat/print');
  Future<List<Map<String, String>>> firewallMangleRules() => getList('/ip/firewall/mangle/print');
  Future<List<Map<String, String>>> routes() => getList('/ip/route/print');
  Future<List<Map<String, String>>> logs() => getList('/log/print');

  Future<void> addHotspotUser({
    required String name,
    required String password,
    required String profile,
    String? comment,
  }) async {
    await send([
      '/ip/hotspot/user/add',
      '=name=$name',
      '=password=$password',
      '=profile=$profile',
      if (comment != null) '=comment=$comment',
    ]);
  }

  Future<void> disconnect() async {
    _connected = false;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('انقطع الاتصال'));
    }
    _pending.clear();
    _responses.clear();
  }
}
