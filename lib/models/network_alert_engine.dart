enum NetworkAlertSeverity { info, warning, critical }

class NetworkAlert {
  final String code;
  final String title;
  final String detail;
  final NetworkAlertSeverity severity;

  const NetworkAlert({
    required this.code,
    required this.title,
    required this.detail,
    required this.severity,
  });
}

/// Deterministic, read-only alert evaluation. Missing inputs never imply health.
class NetworkAlertEngine {
  const NetworkAlertEngine._();

  static List<NetworkAlert> evaluate({
    required List<dynamic> interfaces,
    required List<dynamic> interfaceListMembers,
    int? cpuPercent,
    int? memoryPercent,
    int? temperatureCelsius,
  }) {
    final alerts = <NetworkAlert>[];
    final wanMembers = interfaceListMembers.where((row) {
      return row is Map &&
          row['list']?.toString().toLowerCase() == 'wan' &&
          row['interface']?.toString().isNotEmpty == true;
    }).toList();

    if (wanMembers.isEmpty) {
      alerts.add(const NetworkAlert(
        code: 'wan-members-unknown',
        title: 'قائمة WAN غير محددة',
        detail: 'لم تظهر واجهات ضمن قائمة WAN؛ لا يمكن تأكيد حالة خطوط الإنترنت.',
        severity: NetworkAlertSeverity.info,
      ));
    }

    for (final member in wanMembers) {
      final name = (member as Map)['interface'].toString();
      final matches = interfaces.where((row) => row is Map && row['name']?.toString() == name);
      if (matches.isEmpty) {
        alerts.add(NetworkAlert(
          code: 'wan-interface-missing:$name',
          title: 'تعذّر فحص واجهة WAN',
          detail: 'الواجهة $name موجودة في القائمة لكن بياناتها غير متاحة.',
          severity: NetworkAlertSeverity.warning,
        ));
        continue;
      }
      final row = matches.first as Map;
      final disabled = _truthy(row['disabled']);
      final running = _truthy(row['running']);
      if (!disabled && !running) {
        alerts.add(NetworkAlert(
          code: 'wan-down:$name',
          title: 'خط WAN متوقف',
          detail: 'الواجهة $name غير معطّلة لكنها لا تعرض حالة running.',
          severity: NetworkAlertSeverity.critical,
        ));
      }
    }

    _addThreshold(
      alerts,
      code: 'cpu',
      title: 'استخدام المعالج',
      value: cpuPercent,
      warningAt: 75,
      criticalAt: 90,
      unit: '%',
    );
    _addThreshold(
      alerts,
      code: 'memory',
      title: 'استخدام الذاكرة',
      value: memoryPercent,
      warningAt: 80,
      criticalAt: 92,
      unit: '%',
    );
    _addThreshold(
      alerts,
      code: 'temperature',
      title: 'حرارة الجهاز',
      value: temperatureCelsius,
      warningAt: 75,
      criticalAt: 85,
      unit: '°C',
    );

    return List.unmodifiable(alerts);
  }

  static void _addThreshold(
    List<NetworkAlert> alerts, {
    required String code,
    required String title,
    required int? value,
    required int warningAt,
    required int criticalAt,
    required String unit,
  }) {
    if (value == null || value < 0) {
      alerts.add(NetworkAlert(
        code: '$code-unknown',
        title: '$title غير متاحة',
        detail: 'لا توجد قراءة صالحة؛ لا يمكن اعتبار المؤشر سليماً.',
        severity: NetworkAlertSeverity.info,
      ));
    } else if (value >= criticalAt) {
      alerts.add(NetworkAlert(
        code: '$code-critical',
        title: '$title مرتفع جداً',
        detail: 'القراءة الحالية $value$unit.',
        severity: NetworkAlertSeverity.critical,
      ));
    } else if (value >= warningAt) {
      alerts.add(NetworkAlert(
        code: '$code-warning',
        title: '$title مرتفع',
        detail: 'القراءة الحالية $value$unit.',
        severity: NetworkAlertSeverity.warning,
      ));
    }
  }

  static bool _truthy(dynamic value) {
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == 'yes';
  }
}
