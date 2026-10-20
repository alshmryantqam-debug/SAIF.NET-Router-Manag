import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api/routeros_client.dart';

class TrafficSample {
  final DateTime t;
  final double rx; // bits/s
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
  const RosInterface(this.name, this.running, this.type);
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

  /// تُستدعى من ChangeNotifierProxyProvider عند تغيّر الجلسة.
  void attach(RouterOsClient? c) {
    if (identical(c, _client)) return;
    _timer?.cancel();
    _client = c;
    history.clear();
    events.clear();
    if (c != null) _init();
  }

  Future<void> _init() async {
    try {
      final r = await _client!.get('/interface') as List;
      interfaces = r
          .map((e) => RosInterface(
              e['name'], e['running'] == 'true', (e['type'] ?? '').toString()))
          .toList();
      // افتراضياً: الواجهات الفيزيائية والمراقَبة الأولى
      watched = interfaces
          .where((i) => i.type == 'ether' || i.type == 'sfp-sfpplus')
          .take(4)
          .map((i) => i.name)
          .toList();
      for (final i in interfaces) {
        _lastRunning[i.name] = i.running;
      }
      notifyListeners();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    } on RosException catch (e) {
      events.insert(0, NetEvent(DateTime.now(), e.message, true));
      notifyListeners();
    }
  }

  void toggleWatch(String name) {
    watched.contains(name) ? watched.remove(name) : watched.add(name);
    notifyListeners();
  }

  Future<void> _tick() async {
    if (_busy || _client == null || watched.isEmpty) return;
    _busy = true;
    try {
      final r = await _client!.post('/interface/monitor-traffic', {
        'interface': watched.join(','),
        'once': '',
      }) as List;
      final now = DateTime.now();
      for (final row in r) {
        final name = row['name'] as String;
        final list = history.putIfAbsent(name, () => []);
        list.add(TrafficSample(
          now,
          double.tryParse('${row['rx-bits-per-second']}') ?? 0,
          double.tryParse('${row['tx-bits-per-second']}') ?? 0,
        ));
        if (list.length > maxPoints) list.removeAt(0);
      }
      await _checkLinks();
      notifyListeners();
    } on RosException catch (_) {
      // نتجاهل خطأ دورة واحدة، والتنبيه يأتي من مراقبة الاتصال
    } finally {
      _busy = false;
    }
  }

  Future<void> _checkLinks() async {
    final r = await _client!.get('/interface') as List;
    for (final e in r) {
      final name = e['name'] as String;
      final run = e['running'] == 'true';
      final prev = _lastRunning[name];
      if (prev != null && prev != run && watched.contains(name)) {
        events.insert(
            0,
            NetEvent(DateTime.now(),
                run ? 'عاد الخط $name للعمل' : 'انقطع الخط $name', !run));
        if (events.length > 100) events.removeLast();
      }
      _lastRunning[name] = run;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
