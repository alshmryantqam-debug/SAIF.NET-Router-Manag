enum RouterHealthLevel { healthy, warning, critical, unknown }

class RouterHealthFinding {
  final String metric;
  final RouterHealthLevel level;
  final String title;
  final String detail;
  final String recommendation;

  const RouterHealthFinding({
    required this.metric,
    required this.level,
    required this.title,
    required this.detail,
    required this.recommendation,
  });
}

/// Deterministic, read-only local health checks.
class RouterHealthAssessment {
  final List<RouterHealthFinding> findings;

  const RouterHealthAssessment(this.findings);

  factory RouterHealthAssessment.evaluate({
    int? cpuPercent,
    int? memoryPercent,
    int? temperatureCelsius,
  }) {
    final findings = <RouterHealthFinding>[
      _rangeFinding(
        metric: 'cpu',
        value: cpuPercent,
        criticalAt: 90,
        warningAt: 75,
        title: 'استخدام المعالج',
        unit: '%',
        healthyText: 'استخدام المعالج ضمن النطاق المعتاد.',
        warningText: 'استخدام المعالج مرتفع.',
        criticalText: 'استخدام المعالج مرتفع جداً.',
        recommendation: 'راجع المهام الثقيلة والـ queues وقواعد الجدار الناري قبل تعديل أي إعداد.',
      ),
      _rangeFinding(
        metric: 'memory',
        value: memoryPercent,
        criticalAt: 92,
        warningAt: 80,
        title: 'استخدام الذاكرة',
        unit: '%',
        healthyText: 'استخدام الذاكرة ضمن النطاق المعتاد.',
        warningText: 'الذاكرة المستخدمة مرتفعة.',
        criticalText: 'الذاكرة المستخدمة قريبة من الامتلاء.',
        recommendation: 'راجع الموارد والخدمات والسجلات؛ لا تحذف إعدادات أو سجلات تلقائياً.',
      ),
      _rangeFinding(
        metric: 'temperature',
        value: temperatureCelsius,
        criticalAt: 85,
        warningAt: 75,
        title: 'حرارة الجهاز',
        unit: '°C',
        healthyText: 'درجة الحرارة ضمن النطاق المحدد لهذه المراجعة.',
        warningText: 'درجة حرارة الجهاز مرتفعة.',
        criticalText: 'درجة حرارة الجهاز مرتفعة جداً.',
        recommendation: 'تحقق من التهوية ومكان الجهاز ومراوحه؛ قارن أيضاً بحدود الشركة المصنعة.',
      ),
    ];
    return RouterHealthAssessment(List.unmodifiable(findings));
  }

  RouterHealthLevel get overallLevel {
    if (findings.any((f) => f.level == RouterHealthLevel.critical)) {
      return RouterHealthLevel.critical;
    }
    if (findings.any((f) => f.level == RouterHealthLevel.warning)) {
      return RouterHealthLevel.warning;
    }
    if (findings.any((f) => f.level == RouterHealthLevel.healthy)) {
      return RouterHealthLevel.healthy;
    }
    return RouterHealthLevel.unknown;
  }

  String get overallTitle {
    switch (overallLevel) {
      case RouterHealthLevel.healthy:
        return 'المؤشرات المتاحة مستقرة';
      case RouterHealthLevel.warning:
        return 'تحتاج بعض المؤشرات إلى الانتباه';
      case RouterHealthLevel.critical:
        return 'مؤشر حرج يحتاج إلى مراجعة';
      case RouterHealthLevel.unknown:
        return 'البيانات غير كافية للتقييم';
    }
  }

  static RouterHealthFinding _rangeFinding({
    required String metric,
    required int? value,
    required int criticalAt,
    required int warningAt,
    required String title,
    required String unit,
    required String healthyText,
    required String warningText,
    required String criticalText,
    required String recommendation,
  }) {
    if (value == null || value < 0) {
      return RouterHealthFinding(
        metric: metric,
        level: RouterHealthLevel.unknown,
        title: title,
        detail: 'لا تتوفر قراءة لهذه القيمة.',
        recommendation: 'تحقق من دعم الجهاز لهذا المؤشر وصلاحيات القراءة.',
      );
    }
    if (value >= criticalAt) {
      return RouterHealthFinding(
        metric: metric,
        level: RouterHealthLevel.critical,
        title: title,
        detail: '$criticalText ($value$unit)',
        recommendation: recommendation,
      );
    }
    if (value >= warningAt) {
      return RouterHealthFinding(
        metric: metric,
        level: RouterHealthLevel.warning,
        title: title,
        detail: '$warningText ($value$unit)',
        recommendation: recommendation,
      );
    }
    return RouterHealthFinding(
      metric: metric,
      level: RouterHealthLevel.healthy,
      title: title,
      detail: '$healthyText ($value$unit)',
      recommendation: 'استمر بالمراقبة ولا حاجة لتغيير الإعدادات اعتماداً على هذه القراءة وحدها.',
    );
  }
}
