import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'routeros_rest_api.dart'
    show
        RosRow,
        RouterOsException,
        RouterOsErrorKind,
        isPrivateHost,
        mapNetworkError;

class ApiReply {
  const ApiReply(this.rows, this.doneAttrs);
  final List<RosRow> rows;
  final RosRow doneAttrs;
  String? get ret => doneAttrs['ret'];
}

class _Pending {
  final Completer<ApiReply> completer = Completer<ApiReply>();
  final List<RosRow> rows = [];
  String? trap;
}

class _ByteQueue {
  final List<int> _buf = <int>[];
  int _pos = 0;
  Completer<void>? _waiter;
  Object? _error;
  bool _closed = false;

  int get available => _buf.length - _pos;

  void add(List<int> data) {
    _buf.addAll(data);
    _notify();
  }

  void closeWith(Object error) {
    _closed = true;
    _error ??= error;
    _notify();
  }

  void _notify() {
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<Uint8List> read(int n) async {
    while (available < n) {
      if (_closed) {
        throw _error ??
            const RouterOsException('انقطع الاتصال بالراوتر',
                kind: RouterOsErrorKind.network);
      }
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    final out = Uint8List.fromList(_buf.sublist(_pos, _pos + n));
    _pos += n;
    if (_pos > 65536 && _pos * 2 > _buf.length) {
      _buf.removeRange(0, _pos);
      _pos = 0;
    }
    return out;
  }
}

class RouterOsBinaryApi {
  RouterOsBinaryApi._(this._socket, this.username, this.password, this._timeout);

  final Socket _socket;
  final String username;
  final String password;
  final Duration _timeout;

  final _ByteQueue _queue = _ByteQueue();
  final Map<String, _Pending> _pending = {};
  int _tagCounter = 0;
  bool _closed = false;

  bool get isOpen => !_closed;

  static Future<RouterOsBinaryApi> connect({
    required String host,
    required int port,
    required String username,
    required String password,
    bool useSsl = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Socket socket;
    try {
      if (useSsl) {
        socket = await SecureSocket.connect(
          host,
          port,
          timeout: timeout,
          onBadCertificate: (X509Certificate c) => isPrivateHost(host),
        );
      } else {
        socket = await Socket.connect(host, port, timeout: timeout);
      }
    } catch (e) {
      throw mapNetworkError(e);
    }
    final api = RouterOsBinaryApi._(socket, username, password, timeout);
    api._start();
    try {
      await api._login();
    } catch (e) {
      api.close();
      rethrow;
    }
    return api;
  }

  void _start() {
    try {
      _socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    _socket.listen(
      _queue.add,
      onError: (Object e) => _queue.closeWith(mapNetworkError(e)),
      onDone: () => _queue.closeWith(const RouterOsException(
          'انقطع الاتصال بالراوتر',
          kind: RouterOsErrorKind.network)),
      cancelOnError: true,
    );
    unawaited(_readLoop());
  }

  static List<int> encodeLength(int len) {
    if (len < 0x80) return [len];
    if (len < 0x4000) {
      final v = len | 0x8000;
      return [(v >> 8) & 0xFF, v & 0xFF];
    }
    if (len < 0x200000) {
      final v = len | 0xC00000;
      return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
    }
    if (len < 0x10000000) {
      final v = len | 0xE0000000;
      return [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
    }
    return [
      0xF0,
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
    ];
  }

  static Uint8List encodeSentence(List<String> words) {
    final b = BytesBuilder(copy: false);
    for (final w in words) {
      final data = utf8.encode(w);
      b.add(encodeLength(data.length));
      b.add(data);
    }
    b.addByte(0);
    return b.toBytes();
  }

  Future<int> _readLength() async {
    final b0 = (await _queue.read(1))[0];
    if ((b0 & 0x80) == 0) return b0;
    if ((b0 & 0xC0) == 0x80) {
      final b1 = (await _queue.read(1))[0];
      return ((b0 & 0x3F) << 8) | b1;
    }
    if ((b0 & 0xE0) == 0xC0) {
      final r = await _queue.read(2);
      return ((b0 & 0x1F) << 16) | (r[0] << 8) | r[1];
    }
    if ((b0 & 0xF0) == 0xE0) {
      final r = await _queue.read(3);
      return ((b0 & 0x0F) << 24) | (r[0] << 16) | (r[1] << 8) | r[2];
    }
    if (b0 == 0xF0) {
      final r = await _queue.read(4);
      return (r[0] << 24) | (r[1] << 16) | (r[2] << 8) | r[3];
    }
    throw const RouterOsException('بيانات بروتوكول غير صالحة',
        kind: RouterOsErrorKind.protocol);
  }

  Future<List<String>> _readSentence() async {
    final words = <String>[];
    while (true) {
      final len = await _readLength();
      if (len == 0) break;
      final data = await _queue.read(len);
      words.add(utf8.decode(data, allowMalformed: true));
    }
    return words;
  }

  Future<void> _readLoop() async {
    try {
      while (!_closed) {
        final sentence = await _readSentence();
        _dispatch(sentence);
      }
    } catch (e) {
      _failAll(mapNetworkError(e));
      _closed = true;
    }
  }

  void _dispatch(List<String> words) {
    if (words.isEmpty) return;
    final type = words.first;
    final attrs = <String, String>{};
    var tag = '';
    for (final w in words.skip(1)) {
      if (w.startsWith('.tag=')) {
        tag = w.substring(5);
        continue;
      }
      if (w.startsWith('=')) {
        final i = w.indexOf('=', 1);
        if (i == -1) {
          attrs[w.substring(1)] = '';
        } else {
          attrs[w.substring(1, i)] = w.substring(i + 1);
        }
      }
    }

    if (type == '!fatal') {
      _failAll(RouterOsException(
          'أغلق الراوتر الاتصال: ${words.skip(1).join(' ')}',
          kind: RouterOsErrorKind.network));
      close();
      return;
    }

    final p = _pending[tag];
    if (p == null) return;
    switch (type) {
      case '!re':
        p.rows.add(attrs);
        break;
      case '!trap':
        p.trap = attrs['message'] ?? 'خطأ غير معروف';
        break;
      case '!done':
        _pending.remove(tag);
        if (p.trap != null) {
          p.completer.completeError(_trapError(p.trap!));
        } else {
          p.completer.complete(ApiReply(p.rows, attrs));
        }
        break;
      default:
        break;
    }
  }

  RouterOsException _trapError(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid user') || l.contains('cannot log in')) {
      return const RouterOsException(
          'فشل المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة',
          kind: RouterOsErrorKind.auth);
    }
    if (l.contains('not enough permissions')) {
      return const RouterOsException(
          'صلاحيات المستخدم غير كافية لتنفيذ هذا الأمر',
          kind: RouterOsErrorKind.forbidden);
    }
    return RouterOsException('رد الراوتر: $m',
        kind: RouterOsErrorKind.badRequest);
  }

  void _failAll(Object err) {
    final list = _pending.values.toList();
    _pending.clear();
    for (final p in list) {
      if (!p.completer.isCompleted) p.completer.completeError(err);
    }
  }

  Future<ApiReply> talk(
    List<String> words, {
    bool tagged = true,
    Duration? timeout,
  }) {
    if (_closed) {
      return Future.error(const RouterOsException(
          'الاتصال مغلق، أعد الاتصال بالراوتر',
          kind: RouterOsErrorKind.network));
    }
    final tag = tagged ? (++_tagCounter).toString() : '';
    final p = _Pending();
    _pending[tag] = p;
    final future = p.completer.future.timeout(
      timeout ?? _timeout * 2,
      onTimeout: () {
        _pending.remove(tag);
        throw const RouterOsException('انتهت مهلة انتظار رد الراوتر',
            kind: RouterOsErrorKind.timeout);
      },
    );
    try {
      _socket.add(encodeSentence([...words, if (tagged) '.tag=$tag']));
    } catch (e) {
      _pending.remove(tag);
      if (!p.completer.isCompleted) p.completer.completeError(mapNetworkError(e));
    }
    return future;
  }

  Future<void> _login() async {
    final r = await talk(
      ['/login', '=name=$username', '=password=$password'],
      tagged: false,
    );
    final ret = r.ret;
    if (ret != null && ret.isNotEmpty) {
      final challenge = _hexDecode(ret);
      final digest = md5.convert([0, ...utf8.encode(password), ...challenge]);
      await talk(
        ['/login', '=name=$username', '=response=00$digest'],
        tagged: false,
      );
    }
  }

  static List<int> _hexDecode(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  Future<List<RosRow>> command(
    String path, {
    Map<String, String>? params,
    Map<String, String>? query,
    String? proplist,
  }) async {
    final words = <String>[path];
    params?.forEach((k, v) => words.add('=$k=$v'));
    if (proplist != null) words.add('=.proplist=$proplist');
    query?.forEach((k, v) => words.add('?$k=$v'));
    final r = await talk(words);
    return r.rows;
  }

  Future<String> add(String path, Map<String, String> params) async {
    final words = <String>['$path/add'];
    params.forEach((k, v) => words.add('=$k=$v'));
    final r = await talk(words);
    return r.ret ?? '';
  }

  Future<RosRow> getResource() async {
    final rows = await command('/system/resource/print');
    return rows.isEmpty ? <String, String>{} : rows.first;
  }

  Future<String> getIdentity() async {
    final rows = await command('/system/identity/print');
    return rows.isEmpty ? '' : (rows.first['name'] ?? '');
  }

  Future<List<RosRow>> getHotspotUsers() =>
      command('/ip/hotspot/user/print');

  Future<String> addHotspotUser({
    required String name,
    required String password,
    String profile = 'default',
    String comment = '',
    String limitUptime = '',
    int limitBytesTotal = 0,
  }) {
    final p = <String, String>{
      'name': name,
      'password': password,
      'profile': profile,
    };
    if (comment.isNotEmpty) p['comment'] = comment;
    if (limitUptime.isNotEmpty) p['limit-uptime'] = limitUptime;
    if (limitBytesTotal > 0) p['limit-bytes-total'] = '$limitBytesTotal';
    return add('/ip/hotspot/user', p);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    const err = RouterOsException('تم قطع الاتصال',
        kind: RouterOsErrorKind.network);
    _failAll(err);
    _queue.closeWith(err);
    try {
      _socket.destroy();
    } catch (_) {}
  }
}