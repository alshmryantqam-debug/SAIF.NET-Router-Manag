import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/router_client.dart';
import '../core/api/routeros_client.dart' show RosException;

class TrafficSample {
  final DateTime t;
  final double rx;
  final double tx;
  const TrafficSample(this.t, this.rx, this.tx);
}

class NetEvent {
  final DateTime t;
  final String text;
  final bool bad;
  const NetEvent(this.t, this.text, this.bad);
}

class RosInterface {
  final String name;
  final bool running;
  final String type;
  final bool disabled;

  const RosInterface(
    this.name,
    this.running,
    this.type, {
    this.disabled = false,
  });
}

class TrafficProvider extends ChangeNotifier {
  static const maxPoints = 60;

  RouterOsClient? _client;
  Timer? _timer;
  bool _busy = false;

  List<RosInterface> interfaces = [];
  List<String> watched = [];
  final Map<String, List<TrafficSample>> history = {};
  final List<NetEvent> events = [];
  final Map<String, bool> _lastRunning = {};

  void attach(RouterOsClient? client) {
    if (identical(client, _client)) return;
    _timer?.cancel();
    _timer = null;
    _client = client;
    history.clear();
    events.clear();
    interfaces = [];
    watched = [];
    _lastRunning.clear();
    notifyListeners();
    if (client != null) _init();
  }

  Future<void> _init() async {
    await refreshInterfaces();
    if (_client != null && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    }
  }

  Future<void> refreshInterfaces() async {
    final client = _client;
    if (client == null) {
      interfaces = [];
      watched = [];
      history.clear();
      _lastRunning.clear();
      notifyListeners();
      return;
    }

    try {
      final dynamic response = await client.get('/interface');
      if (!identical(client, _client)) return;
      final rows = _rows(response);
      interfaces = rows
          .map((row) => RosInterface(
                (row['name'] ?? '').toString(),
                _isTrue(row['running']),
                (row['type'] ?? '').toString(),
                disabled: _isTrue(row['disabled']),
              ))
          .where((item) => item.name.isNotEmpty)
          .toList();

      watched.removeWhere((name) => !interfaces.any((item) => item.name == name));
      if (watched.isEmpty && interfaces.isNotEmpty) {
        final physical = interfaces.where((item) {
          final type = item.type.toLowerCase();
          return type.contains('ether') || type.contains('sfp') ||
              item.name.toLowerCase().startsWith('ether') ||
              item.name.toLowerCase().startsWith('sfp');
        });
        watched = [
          physical.isNotEmpty ? physical.first.name : interfaces.first.name,
        ];
      } else if (watched.length > 1) {
        watched = [watched.first];
      }

      _lastRunning
        ..clear()
        ..addEntries(interfaces.map((item) => MapEntry(item.name, item.running)));
      notifyListeners();
    } on RosException catch (error) {
      _addEvent(error.message, true);
    } catch (error) {
      _addEvent('تعذر تحديث واجهات الراوتر: $error', true);
    }
  }

  void selectInterface(String name) {
    if (!interfaces.any((item) => item.name == name)) return;
    if (watched.length == 1 && watched.first == name) return;
    watched = [name];
    history.removeWhere((key, _) => key != name);
    notifyListeners();
    _tick();
  }

  void toggleWatch(String name) => selectInterface(name);

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (response is Map) return [Map<String, dynamic>.from(response)];
    return [];
  }

  bool _isTrue(dynamic value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  double _parseRate(dynamic value) {
    if (value is num) return value.toDouble();
    final text = (value ?? '').toString().trim().toLowerCase().replaceAll(' ', '');
    final match = RegExp(r'^([0-9]+(?:[.][0-9]+)?)([kmgt]?)')
        .firstMatch(text);
    if (match == null) return double.tryParse(text) ?? 0;

    final number = double.tryParse(match.group(1) ?? '') ?? 0;
    final prefix = match.group(2);
    final multiplier = switch (prefix) {
      'k' => 1000.0,
      'm' => 1000000.0,
      'g' => 1000000000.0,
      't' => 1000000000000.0,
      _ => 1.0,
    };
    return number * multiplier;
  }

  Future<bool> sampleNow() => _tick();

  Future<bool> _tick() async {
    final client = _client;
    if (_busy || client == null || watched.isEmpty) return false;
    _busy = true;
    var receivedSample = false;
    try {
      final dynamic response = await client.post('/interface/monitor-traffic', {
        'interface': watched.first,
        'once': '',
      });
      if (!identical(client, _client)) return false;
      final rows = _rows(response);
      final now = DateTime.now();
      for (final row in rows) {
        final name = (row['name'] ?? watched.first).toString();
        final samples = history.putIfAbsent(name, () => <TrafficSample>[]);
        samples.add(TrafficSample(
          now,
          _parseRate(row['rx-bits-per-second']),
          _parseRate(row['tx-bits-per-second']),
        ));
        if (samples.length > maxPoints) samples.removeAt(0);
        receivedSample = true;
      }
      await _checkLinks(client);
      notifyListeners();
      return receivedSample;
    } on RosException catch (error) {
      if (events.isEmpty || events.first.text != error.message) {
        _addEvent('تعذرت قراءة حركة الواجهة: ' + error.message, true);
      }
      return false;
    } catch (_) {
      // Keep the last valid sample after a transient polling failure.
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> _checkLinks(RouterOsClient client) async {
    final dynamic response = await client.get('/interface');
    if (!identical(client, _client)) return;
    for (final item in _rows(response)) {
      final name = (item['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final running = _isTrue(item['running']);
      final previous = _lastRunning[name];
      if (previous != null && previous != running && watched.contains(name)) {
        _addEvent(
          running ? 'عاد الخط ' + name + ' للعمل' : 'انقطع الخط ' + name,
          !running,
        );
      }
      _lastRunning[name] = running;
    }
  }

  void _addEvent(String message, bool bad) {
    events.insert(0, NetEvent(DateTime.now(), message, bad));
    if (events.length > 50) events.removeLast();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
