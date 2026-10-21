import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_provider.dart';

enum TrafficCategory { gaming, social, streaming }

class QuantumDominationProvider extends ChangeNotifier {
  QuantumDominationProvider(this._connection);

  final ConnectionProvider _connection;
  Timer? _poller;
  bool _disposed = false;
  bool _loading = false;
  bool _applying = false;
  String _error = '';
  List<Map<String, dynamic>> _queues = const [];
  Map<String, int> _rates = const {'gaming': 0, 'social': 0, 'streaming': 0};
  Map<String, int> _previousBytes = {};
  DateTime? _previousSample;

  bool get isLoading => _loading;
  bool get isApplying => _applying;
  String get error => _error;
  bool get connected => _connection.isConnected;
  List<Map<String, dynamic>> get queues => List.unmodifiable(_queues);
  int get gamingRate => _rates['gaming'] ?? 0;
  int get socialRate => _rates['social'] ?? 0;
  int get streamingRate => _rates['streaming'] ?? 0;

  double get gamingLoad => _normalise(gamingRate);
  double get socialLoad => _normalise(socialRate);
  double get streamingLoad => _normalise(streamingRate);

  double _normalise(int rate) {
    final maxRate = [gamingRate, socialRate, streamingRate].fold<int>(
      0, (max, value) => value > max ? value : max);
    if (maxRate <= 0) return 0;
    return (rate / maxRate).clamp(0.0, 1.0).toDouble();
  }

  Map<String, dynamic>? queueFor(TrafficCategory category) {
    final keys = switch (category) {
      TrafficCategory.gaming => ['game', 'gaming', 'pubg', 'playstation', 'xbox', 'لعب', 'العاب'],
      TrafficCategory.social => ['social', 'tiktok', 'facebook', 'instagram', 'whatsapp', 'تواصل'],
      TrafficCategory.streaming => ['stream', 'video', 'netflix', 'youtube', 'بث', 'فيديو'],
    };
    for (final queue in _queues) {
      final text = '${queue['name'] ?? ''} ${queue['comment'] ?? ''}'.toLowerCase();
      if (keys.any(text.contains)) return queue;
    }
    return null;
  }

  int? currentLimitMbps(TrafficCategory category) {
    final value = queueFor(category)?['max-limit']?.toString() ?? '';
    final match = RegExp(r'^(\\d+(?:\\.\\d+)?)([kKmMgG]?)').firstMatch(value);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1) ?? '');
    if (amount == null) return null;
    final unit = (match.group(2) ?? '').toLowerCase();
    final mbps = switch (unit) {
      'g' => amount * 1000,
      'k' => amount / 1000,
      _ => amount,
    };
    return mbps.round().clamp(1, 1000);
  }

  int? currentPriority(TrafficCategory category) =>
      int.tryParse(queueFor(category)?['priority']?.toString() ?? '');

  Future<void> start() async {
    _poller ??= Timer.periodic(const Duration(seconds: 3), (_) {
      refresh(silent: true);
    });
    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (_loading || !connected) {
      if (!connected && !silent) {
        _error = 'اتصل بالراوتر أولاً لقراءة شجرة الطوابير الحقيقية.';
        _safeNotify();
      }
      return;
    }
    _loading = true;
    if (!silent) _error = '';
    _safeNotify();
    try {
      final raw = await _connection.getQueueTrees();
      final now = DateTime.now();
      final nextQueues = raw.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => (row['.id']?.toString() ?? '').isNotEmpty)
          .toList(growable: false);
      final nextBytes = <String, int>{};
      final byteDeltas = <String, int>{};
      for (final row in nextQueues) {
        final id = row['.id'].toString();
        final bytes = int.tryParse(row['bytes']?.toString() ?? '') ?? 0;
        nextBytes[id] = bytes;
        final before = _previousBytes[id];
        byteDeltas[id] = before == null || bytes < before ? 0 : bytes - before;
      }
      final elapsed = _previousSample == null
          ? 0.0
          : now.difference(_previousSample!).inMilliseconds / 1000.0;
      int categoryRate(TrafficCategory category) {
        final queue = nextQueues.cast<Map<String, dynamic>?>().firstWhere(
          (q) {
            final keys = switch (category) {
              TrafficCategory.gaming => ['game', 'gaming', 'pubg', 'playstation', 'xbox', 'لعب', 'العاب'],
              TrafficCategory.social => ['social', 'tiktok', 'facebook', 'instagram', 'whatsapp', 'تواصل'],
              TrafficCategory.streaming => ['stream', 'video', 'netflix', 'youtube', 'بث', 'فيديو'],
            };
            final text = '${q?['name'] ?? ''} ${q?['comment'] ?? ''}'.toLowerCase();
            return keys.any(text.contains);
          }, orElse: () => null);
        if (queue == null || elapsed <= 0) return 0;
        final id = queue['.id'].toString();
        return ((byteDeltas[id] ?? 0) * 8 / elapsed / 1000000).round();
      }
      _queues = nextQueues;
      _rates = {
        'gaming': categoryRate(TrafficCategory.gaming),
        'social': categoryRate(TrafficCategory.social),
        'streaming': categoryRate(TrafficCategory.streaming),
      };
      _previousBytes = nextBytes;
      _previousSample = now;
      if (_queues.isEmpty) {
        _error = 'لا توجد عناصر في شجرة الطوابير؛ لم يتم إنشاء قواعد تلقائياً.';
      }
    } catch (e) {
      _error = 'تعذر قراءة شجرة الطوابير من الراوتر: ${_safeError(e)}';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<bool> setLimit(TrafficCategory category, int mbps) async {
    if (!connected || mbps < 1 || mbps > 1000) {
      _error = 'تحقق من الاتصال وحد السرعة المحدد.';
      _safeNotify();
      return false;
    }
    final queue = queueFor(category);
    if (queue == null) {
      _error = 'لا يوجد طابور موجود لهذه الفئة. أنشئ قواعد التصنيف يدوياً أولاً؛ لم نغيّر إعدادات أخرى.';
      _safeNotify();
      return false;
    }
    return _apply(queue, maxLimit: '${mbps}M');
  }

  Future<bool> enableGamingPriority(bool enabled) async {
    if (!connected) {
      _error = 'اتصل بالراوتر أولاً.';
      _safeNotify();
      return false;
    }
    final queue = queueFor(TrafficCategory.gaming);
    if (queue == null) {
      _error = 'لا يوجد طابور ألعاب جاهز. لم يتم إنشاء قواعد تصنيف أو تغييرها.';
      _safeNotify();
      return false;
    }
    return _apply(queue, priority: enabled ? 1 : 8);
  }

  Future<bool> _apply(Map<String, dynamic> queue, {String? maxLimit, int? priority}) async {
    if (_applying) return false;
    _applying = true;
    _error = '';
    _safeNotify();
    try {
      await _connection.updateQueueTree(
        id: queue['.id'].toString(),
        maxLimit: maxLimit,
        priority: priority,
      );
      await refresh();
      if (_error.isNotEmpty) return false;
      return true;
    } catch (e) {
      _error = 'رفض الراوتر التغيير: ${_safeError(e)}';
      return false;
    } finally {
      _applying = false;
      _safeNotify();
    }
  }

  String _safeError(Object error) {
    final text = error.toString();
    if (text.contains('Authorization') || text.contains('password')) {
      return 'تحقق من صلاحيات المستخدم واتصال الراوتر.';
    }
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poller?.cancel();
    super.dispose();
  }
}
