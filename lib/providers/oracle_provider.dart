import 'package:flutter/foundation.dart';

import 'connection_provider.dart';

enum OracleSeverity { critical, warning, info }

class NetworkAnomaly {
  final String id;
  final String title;
  final String description;
  final OracleSeverity severity;
  final String suggestedAction;
  final String evidence;
  final String? interfaceId;
  final String? interfaceName;
  bool isResolved;

  NetworkAnomaly({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.suggestedAction,
    required this.evidence,
    this.interfaceId,
    this.interfaceName,
    this.isResolved = false,
  });
}

/// تشخيص مبني على أدلة RouterOS. المسح للقراءة فقط ولا يعطّل المنافذ تلقائياً.
class OracleProvider extends ChangeNotifier {
  final ConnectionProvider _connection;
  OracleProvider(this._connection);

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  bool _isHealing = false;
  bool get isHealing => _isHealing;
  bool _hasScanned = false;
  bool get hasScanned => _hasScanned;
  List<NetworkAnomaly> _anomalies = [];
  List<NetworkAnomaly> get anomalies => List.unmodifiable(_anomalies);
  String _oracleStatus = 'أوراكل في وضع السبات. بانتظار اتصال موثوق بالراوتر.';
  String get oracleStatus => _oracleStatus;
  DateTime? _lastScan;
  DateTime? get lastScan => _lastScan;

  Future<void> initiateDeepScan() async {
    if (_isScanning || _isHealing) return;
    if (!_connection.isConnected) {
      _oracleStatus = 'تعذر المسح: اتصل بالراوتر أولاً.';
      notifyListeners();
      return;
    }

    _isScanning = true;
    _anomalies = [];
    _oracleStatus = 'جارٍ جمع سجلات النظام وواجهات الشبكة وموارد المعالج...';
    notifyListeners();

    try {
      await _connection.fetchSystemResource();
      final results = await Future.wait([
        _connection.getRouterLogs(),
        _connection.getInterfacesFromRouter(),
      ]);
      final logs = results[0];
      final interfaces = results[1];
      final resource = _connection.systemResource;
      final cpu = _number(resource['cpu-load']);
      final findings = <NetworkAnomaly>[];

      final loopLogs = _matchingLogs(logs, ['loop', 'bridge loop', 'loop-protect']);
      if (loopLogs.isNotEmpty) {
        findings.add(NetworkAnomaly(
          id: 'loop-${loopLogs.length}',
          title: 'اشتباه حلقة من الطبقة الثانية',
          description: 'تحتوي سجلات الراوتر على إشارات مرتبطة بحلقة شبكية. السجل وحده لا يحدد المنفذ المسبب بشكل قاطع.',
          severity: OracleSeverity.critical,
          suggestedAction: 'تحقق من وصلات الجسور وفعّل Loop Protect بعد مراجعة طوبولوجيا الشبكة.',
          evidence: _logEvidence(loopLogs),
        ));
      }

      final stormLogs = _matchingLogs(logs, ['broadcast storm', 'packet storm', 'excessive broadcast']);
      if (stormLogs.isNotEmpty) {
        findings.add(NetworkAnomaly(
          id: 'storm-${stormLogs.length}',
          title: 'إشارة إلى عاصفة بث',
          description: 'عُثر على رسائل سجل تشير إلى تدفق بث غير طبيعي. لم يتم عزل أي واجهة.',
          severity: OracleSeverity.critical,
          suggestedAction: 'افحص معدلات البث على المنافذ والجسور باستخدام Torch أو مراقبة الحركة قبل العزل.',
          evidence: _logEvidence(stormLogs),
        ));
      }

      final conflictLogs = _matchingLogs(logs, ['mac conflict', 'duplicate mac', 'duplicate address']);
      if (conflictLogs.isNotEmpty) {
        findings.add(NetworkAnomaly(
          id: 'mac-${conflictLogs.length}',
          title: 'اشتباه تعارض عنوان',
          description: 'رُصدت رسائل في السجل تتعلق بعنوان مكرر أو تعارض MAC.',
          severity: OracleSeverity.warning,
          suggestedAction: 'طابق العنوان مع سجلات DHCP/PPPoE قبل حظر أي جهاز.',
          evidence: _logEvidence(conflictLogs),
        ));
      }

      if (cpu >= 85) {
        findings.add(NetworkAnomaly(
          id: 'cpu-${cpu.round()}',
          title: 'ارتفاع حاد في حمل المعالج',
          description: 'حمل المعالج الحالي ${cpu.toStringAsFixed(0)}% وفق قراءة موارد النظام.',
          severity: OracleSeverity.critical,
          suggestedAction: 'افحص Torch وقواعد الجدار الناري والطوابير؛ لا يمكن تحديد السبب من نسبة CPU وحدها.',
          evidence: 'system/resource: cpu-load=${cpu.toStringAsFixed(0)}%',
        ));
      }

      final downInterfaces = interfaces.whereType<Map>().where((row) {
        final disabled = row['disabled']?.toString().toLowerCase() == 'true';
        final running = row['running']?.toString().toLowerCase() == 'true';
        final name = row['name']?.toString() ?? '';
        return !disabled && name.isNotEmpty && !running && _looksPhysical(name);
      }).toList();

      for (final row in downInterfaces.take(5)) {
        final name = row['name']?.toString() ?? 'واجهة غير معروفة';
        findings.add(NetworkAnomaly(
          id: 'link-$name',
          title: 'واجهة فعلية غير عاملة',
          description: 'الواجهة $name مفعّلة إدارياً لكن حالة التشغيل غير نشطة.',
          severity: OracleSeverity.warning,
          suggestedAction: 'تحقق من الطاقة والكابل والطرف المقابل قبل إعادة تفعيل أي إعداد.',
          evidence: 'interface: name=$name, running=${row['running']}, disabled=${row['disabled']}',
          interfaceId: row['.id']?.toString(),
          interfaceName: name,
        ));
      }

      _anomalies = findings;
      _hasScanned = true;
      _lastScan = DateTime.now();
      _oracleStatus = findings.isEmpty
          ? 'اكتمل الفحص دون العثور على مؤشرات من المصادر المتاحة. هذا لا يثبت خلو الشبكة من الأعطال.'
          : 'اكتمل الفحص: رُصدت ${findings.length} مؤشرات. راجع الدليل قبل أي إجراء تغييري.';
    } catch (error) {
      _oracleStatus = 'فشل المسح: تعذر قراءة أحد مصادر RouterOS. $error';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// إعادة تحقق آمنة: لا فصل للمشتركين ولا تعطيل منافذ أو تغيير مسارات.
  Future<void> executeAutoHeal(String anomalyId) async {
    if (_isHealing || _isScanning) return;
    final index = _anomalies.indexWhere((item) => item.id == anomalyId);
    if (index < 0 || _anomalies[index].isResolved) return;
    if (!_connection.isConnected) {
      _oracleStatus = 'تعذر التحقق: الراوتر غير متصل.';
      notifyListeners();
      return;
    }

    _isHealing = true;
    _oracleStatus = 'جارٍ التحقق من المؤشر مجدداً قبل اعتماد زواله...';
    notifyListeners();
    try {
      await _connection.fetchSystemResource();
      final logs = await _connection.getRouterLogs();
      final item = _anomalies[index];
      var stillPresent = true;

      if (item.id.startsWith('cpu-')) {
        stillPresent = _number(_connection.systemResource['cpu-load']) >= 85;
      } else if (item.id.startsWith('loop-')) {
        stillPresent = _matchingLogs(logs, ['loop', 'bridge loop', 'loop-protect']).isNotEmpty;
      } else if (item.id.startsWith('storm-')) {
        stillPresent = _matchingLogs(logs, ['broadcast storm', 'packet storm', 'excessive broadcast']).isNotEmpty;
      } else if (item.id.startsWith('mac-')) {
        stillPresent = _matchingLogs(logs, ['mac conflict', 'duplicate mac', 'duplicate address']).isNotEmpty;
      } else {
        final interfaces = await _connection.getInterfacesFromRouter();
        stillPresent = interfaces.whereType<Map>().any((row) =>
          row['name']?.toString() == item.interfaceName &&
          row['disabled']?.toString().toLowerCase() != 'true' &&
          row['running']?.toString().toLowerCase() != 'true');
      }

      if (!stillPresent) {
        item.isResolved = true;
        _oracleStatus = 'اختفى المؤشر من القياسات الجديدة. تم توثيق زواله؛ لم تُعدّل إعدادات الراوتر.';
      } else {
        _oracleStatus = 'المؤشر ما زال قائماً. لم يُنفذ تغيير تلقائي قد يقطع الخدمة؛ اتبع إجراء المعالجة المقترح.';
      }
    } catch (error) {
      _oracleStatus = 'تعذر التحقق من نتيجة المعالجة: $error';
    } finally {
      _isHealing = false;
      notifyListeners();
    }
  }

  static List<Map> _matchingLogs(List<dynamic> logs, List<String> needles) {
    return logs.whereType<Map>().where((row) {
      final text = '${row['message'] ?? ''} ${row['topics'] ?? ''}'.toLowerCase();
      return needles.any(text.contains);
    }).toList();
  }

  static String _logEvidence(List<Map> rows) {
    return rows.take(3).map((row) =>
      '${row['time'] ?? '?'} | ${row['topics'] ?? 'log'} | ${row['message'] ?? ''}'
    ).join('\n');
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static bool _looksPhysical(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('ether') || lower.startsWith('sfp') ||
        lower.startsWith('wlan') || lower.startsWith('wifi');
  }
}
