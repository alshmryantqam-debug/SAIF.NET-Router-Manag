import '../../services/mikrotik_service.dart';

/// Severity of a finding produced from live, read-only RouterOS data.
enum RouterFindingSeverity { info, warning, critical }

class RouterHealthFinding {
  const RouterHealthFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.details,
    required this.recommendation,
    this.subject,
  });

  final String code;
  final RouterFindingSeverity severity;
  final String title;
  final String details;
  final String recommendation;
  final String? subject;
}

/// Deterministic, read-only health analysis. This class never sends commands
/// to RouterOS and never changes router configuration.
class RouterHealthAnalyzer {
  const RouterHealthAnalyzer({
    this.cpuWarningPercent = 75,
    this.cpuCriticalPercent = 90,
    this.memoryWarningPercent = 80,
    this.memoryCriticalPercent = 90,
    this.diskWarningPercent = 85,
    this.diskCriticalPercent = 95,
  });

  final int cpuWarningPercent;
  final int cpuCriticalPercent;
  final int memoryWarningPercent;
  final int memoryCriticalPercent;
  final int diskWarningPercent;
  final int diskCriticalPercent;

  List<RouterHealthFinding> analyze({
    required SystemResource resources,
    required List<InterfaceInfo> interfaces,
    required List<Map<String, String>> queues,
    Set<String> wanInterfaces = const <String>{},
  }) {
    final findings = <RouterHealthFinding>[];

    if (resources.cpuLoad >= cpuCriticalPercent) {
      findings.add(RouterHealthFinding(
        code: 'cpu-critical',
        severity: RouterFindingSeverity.critical,
        title: 'استهلاك المعالج مرتفع جداً',
        details: 'استخدام CPU وصل إلى ${resources.cpuLoad}%.',
        recommendation:
            'افحص Profile وعمليات الراوتر وسجل النظام قبل تعديل أي قواعد.',
      ));
    } else if (resources.cpuLoad >= cpuWarningPercent) {
      findings.add(RouterHealthFinding(
        code: 'cpu-high',
        severity: RouterFindingSeverity.warning,
        title: 'استهلاك المعالج مرتفع',
        details: 'استخدام CPU وصل إلى ${resources.cpuLoad}%.',
        recommendation:
            'راقب الحمل وقت الذروة وافحص قواعد Firewall وMangle والصفوف.',
      ));
    }

    final memoryPercent = resources.memUsedPercent.round();
    if (resources.totalMemory > 0 &&
        memoryPercent >= memoryCriticalPercent) {
      findings.add(RouterHealthFinding(
        code: 'memory-critical',
        severity: RouterFindingSeverity.critical,
        title: 'الذاكرة شبه ممتلئة',
        details: 'استخدام الذاكرة وصل إلى $memoryPercent%.',
        recommendation:
            'راجع العمليات والاتصالات وسجل النظام، ولا تعِد تشغيل الراوتر قبل جمع الأدلة.',
      ));
    } else if (resources.totalMemory > 0 &&
        memoryPercent >= memoryWarningPercent) {
      findings.add(RouterHealthFinding(
        code: 'memory-high',
        severity: RouterFindingSeverity.warning,
        title: 'استهلاك الذاكرة مرتفع',
        details: 'استخدام الذاكرة وصل إلى $memoryPercent%.',
        recommendation: 'راقب الذاكرة بمرور الوقت وافحص أي ارتفاع مستمر.',
      ));
    }

    if (resources.totalHdd > 0) {
      final diskPercent = ((resources.totalHdd - resources.freeHdd) /
              resources.totalHdd *
              100)
          .clamp(0, 100)
          .round();
      if (diskPercent >= diskCriticalPercent) {
        findings.add(RouterHealthFinding(
          code: 'disk-critical',
          severity: RouterFindingSeverity.critical,
          title: 'مساحة التخزين شبه ممتلئة',
          details: 'استخدام التخزين وصل إلى $diskPercent%.',
          recommendation:
              'راجع الملفات والسجلات والنسخ الاحتياطية قبل حذف أي شيء.',
        ));
      } else if (diskPercent >= diskWarningPercent) {
        findings.add(RouterHealthFinding(
          code: 'disk-high',
          severity: RouterFindingSeverity.warning,
          title: 'مساحة التخزين منخفضة',
          details: 'استخدام التخزين وصل إلى $diskPercent%.',
          recommendation: 'حدد الملفات الكبيرة أولاً، ولا تحذف ملفات مجهولة.',
        ));
      }
    }

    final byName = <String, InterfaceInfo>{
      for (final interface in interfaces) interface.name: interface,
    };
    for (final wan in wanInterfaces) {
      final interface = byName[wan];
      if (interface == null) {
        findings.add(RouterHealthFinding(
          code: 'wan-not-found',
          severity: RouterFindingSeverity.warning,
          title: 'واجهة WAN المحددة غير موجودة',
          details: 'لم تظهر الواجهة "$wan" في بيانات الراوتر.',
          recommendation:
              'تحقق من اسم الواجهة أو صلاحيات الحساب؛ لم يتم إجراء أي تغيير.',
          subject: wan,
        ));
      } else if (interface.disabled || !interface.running) {
        findings.add(RouterHealthFinding(
          code: 'wan-down',
          severity: RouterFindingSeverity.critical,
          title: 'خط إنترنت غير عامل',
          details: interface.disabled
              ? 'واجهة WAN "$wan" معطّلة.'
              : 'واجهة WAN "$wan" ليست بحالة Running.',
          recommendation:
              'تحقق من الكابل والمودم وحالة الواجهة والتوجيه قبل إعادة التفعيل.',
          subject: wan,
        ));
      }
    }

    for (final queue in queues) {
      final name = (queue['name'] ?? '').trim();
      final comment = (queue['comment'] ?? '').trim();
      final limit = (queue['max-limit'] ?? '').replaceAll(' ', '');
      final hint = '${name.toLowerCase()} ${comment.toLowerCase()}';
      final explicitlyOpen = hint.contains('open') ||
          hint.contains('unlimited') ||
          hint.contains('مفتوح') ||
          hint.contains('غير محدود');
      if (limit == '0/0' && explicitlyOpen) {
        findings.add(RouterHealthFinding(
          code: 'unlimited-queue',
          severity: RouterFindingSeverity.warning,
          title: 'صف سرعة يبدو مفتوحاً بلا حد',
          details:
              'الصف "${name.isEmpty ? 'بلا اسم' : name}" يحمل max-limit=0/0 مع تسمية تشير إلى فتح السرعة.',
          recommendation:
              'تحقق من سياسة الاشتراك المقصودة وقارنها بالإعداد المعتمد؛ لا تغيّر الحد تلقائياً.',
          subject: name.isEmpty ? null : name,
        ));
      }
    }

    if (findings.isEmpty) {
      findings.add(const RouterHealthFinding(
        code: 'no-findings',
        severity: RouterFindingSeverity.info,
        title: 'لم تُكتشف مؤشرات تتجاوز حدود الفحص',
        details:
            'النتيجة مبنية فقط على البيانات التي أمكن قراءتها في هذه الجولة.',
        recommendation:
            'استمر بالمراقبة؛ هذه النتيجة ليست ضماناً بأن جميع إعدادات الشبكة سليمة.',
      ));
    }

    return List<RouterHealthFinding>.unmodifiable(findings);
  }
}

/// Runs the analyzer against live router reads. All calls are read-only.
/// WAN names must be supplied from the operator's known configuration; the
/// audit deliberately does not guess which interfaces carry production traffic.
class RouterHealthAuditService {
  const RouterHealthAuditService(
    MikrotikService service, {
    RouterHealthAnalyzer analyzer = const RouterHealthAnalyzer(),
  })  : _service = service,
        _analyzer = analyzer;

  final MikrotikService _service;
  final RouterHealthAnalyzer _analyzer;

  Future<List<RouterHealthFinding>> run({
    Set<String> wanInterfaces = const <String>{},
  }) async {
    final results = await Future.wait<Object>([
      _service.systemResource(),
      _service.interfaces(),
      _service.simpleQueues(),
    ]);

    return _analyzer.analyze(
      resources: results[0] as SystemResource,
      interfaces: results[1] as List<InterfaceInfo>,
      queues: results[2] as List<Map<String, String>>,
      wanInterfaces: wanInterfaces,
    );
  }
}

