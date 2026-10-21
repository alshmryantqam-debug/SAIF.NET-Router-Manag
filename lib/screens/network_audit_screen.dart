import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../widgets/glass_card.dart';

class NetworkAuditScreen extends StatefulWidget {
  const NetworkAuditScreen({super.key});

  @override
  State<NetworkAuditScreen> createState() => _NetworkAuditScreenState();
}

class _NetworkAuditScreenState extends State<NetworkAuditScreen> {
  bool _loading = false;
  DateTime? _lastRun;
  final List<_AuditFinding> _findings = [];
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastRun == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runAudit();
      });
    }
  }

  Future<void> _runAudit() async {
    final client = context.read<ConnectionProvider>().client;
    if (client == null) {
      setState(() {
        _error = 'اتصل بالراوتر أولاً ثم أعد الفحص.';
        _findings.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _findings.clear();
    });

    final findings = <_AuditFinding>[];
    Future<List<Map<String, dynamic>>> readRows(String path) async {
      final dynamic value = await client.get(path);
      if (value is List) {
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (value is Map) return [Map<String, dynamic>.from(value)];
      return <Map<String, dynamic>>[];
    }

    try {
      // Read-only audit: this screen never changes RouterOS configuration.
      final resourceRows = await readRows('system/resource');
      final resource = resourceRows.isEmpty ? <String, dynamic>{} : resourceRows.first;
      final cpu = double.tryParse((resource['cpu-load'] ?? '').toString());
      if (cpu == null) {
        findings.add(const _AuditFinding('مراقبة المعالج', 'تعذر قراءة حمل CPU', _Level.info));
      } else if (cpu >= 90) {
        findings.add(_AuditFinding('حمل المعالج', 'مرتفع جداً: ${cpu.toStringAsFixed(0)}%', _Level.critical));
      } else if (cpu >= 75) {
        findings.add(_AuditFinding('حمل المعالج', 'مرتفع: ${cpu.toStringAsFixed(0)}%', _Level.warning));
      } else {
        findings.add(_AuditFinding('حمل المعالج', 'طبيعي: ${cpu.toStringAsFixed(0)}%', _Level.ok));
      }

      final interfaces = await readRows('interface');
      final physical = interfaces.where((row) {
        final name = (row['name'] ?? '').toString().toLowerCase();
        final type = (row['type'] ?? '').toString().toLowerCase();
        final disabled = (row['disabled'] ?? 'false').toString() == 'true';
        return !disabled && (name.startsWith('ether') || name.startsWith('sfp') ||
            type.contains('ether') || type.contains('sfp'));
      }).toList();
      final down = physical.where((row) => (row['running'] ?? 'false').toString() != 'true').length;
      findings.add(_AuditFinding(
        'المنافذ الفيزيائية',
        '${physical.length - down} يعمل من أصل ${physical.length}؛ المتوقف: $down',
        down == 0 ? _Level.ok : _Level.warning,
      ));

      final routes = await readRows('ip/route');
      final defaults = routes.where((row) {
        final dst = (row['dst-address'] ?? '').toString();
        return (dst == '0.0.0.0/0' || dst == '::/0') &&
            (row['active'] ?? 'false').toString() == 'true';
      }).length;
      findings.add(_AuditFinding(
        'المسارات الافتراضية',
        defaults == 0 ? 'لم يُعثر على مسار افتراضي نشط' : 'المسارات الافتراضية النشطة: $defaults',
        defaults == 0 ? _Level.critical : _Level.ok,
      ));

      final nat = await readRows('ip/firewall/nat');
      final enabledNat = nat.where((row) => (row['disabled'] ?? 'false').toString() != 'true').toList();
      final masquerade = enabledNat.where((row) =>
          (row['action'] ?? '').toString().toLowerCase() == 'masquerade').length;
      findings.add(_AuditFinding(
        'قواعد NAT',
        enabledNat.isEmpty ? 'لا توجد قواعد NAT مفعلة' : 'القواعد المفعلة: ${enabledNat.length}؛ masquerade: $masquerade',
        enabledNat.isEmpty ? _Level.warning : _Level.info,
      ));

      final filter = await readRows('ip/firewall/filter');
      final enabledFilter = filter.where((row) => (row['disabled'] ?? 'false').toString() != 'true').length;
      findings.add(_AuditFinding(
        'جدار الحماية',
        enabledFilter == 0 ? 'لم تُعثر على قواعد فلترة مفعلة' : 'قواعد الفلترة المفعلة: $enabledFilter',
        enabledFilter == 0 ? _Level.warning : _Level.ok,
      ));

      final mangle = await readRows('ip/firewall/mangle');
      final enabledMangle = mangle.where((row) => (row['disabled'] ?? 'false').toString() != 'true').toList();
      final pcc = enabledMangle.where((row) =>
          (row['per-connection-classifier'] ?? '').toString().isNotEmpty).length;
      findings.add(_AuditFinding(
        'توجيه PCC',
        pcc == 0 ? 'لم تُكتشف قواعد PCC واضحة؛ تحقق من أسلوب توزيع الخطوط' : 'قواعد PCC النشطة المكتشفة: $pcc',
        pcc == 0 ? _Level.info : _Level.ok,
      ));

      final queues = await readRows('queue/simple');
      final enabledQueues = queues.where((row) => (row['disabled'] ?? 'false').toString() != 'true').length;
      findings.add(_AuditFinding('Simple Queues', 'الطوابير المفعلة: $enabledQueues', _Level.info));

      final logs = await readRows('log');
      final errors = logs.where((row) {
        final topics = (row['topics'] ?? '').toString().toLowerCase();
        return topics.contains('error') || topics.contains('critical');
      }).take(5).length;
      findings.add(_AuditFinding(
        'سجل الأخطاء',
        'أحداث الخطأ/الحرجة ضمن أحدث العناصر المعروضة: $errors',
        errors > 0 ? _Level.warning : _Level.info,
      ));

      if (!mounted) return;
      setState(() {
        _findings.addAll(findings);
        _lastRun = DateTime.now();
      });
    } on RosException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إكمال الفحص: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<ConnectionProvider>().isConnected;
    final critical = _findings.where((f) => f.level == _Level.critical).length;
    final warning = _findings.where((f) => f.level == _Level.warning).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز تدقيق الشبكة'),
        actions: [IconButton(tooltip: 'إعادة الفحص', onPressed: _loading ? null : _runAudit, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _runAudit,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.health_and_safety_rounded, color: NovaColors.primary, size: 28),
                const SizedBox(width: 10),
                const Expanded(child: Text('تدقيق تشخيصي آمن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                _Pill(connected ? 'متصل' : 'غير متصل', connected ? _Level.ok : _Level.critical),
              ]),
              const SizedBox(height: 8),
              const Text('قراءة فقط: لا يغيّر قواعد الراوتر ولا يوقف المشتركين ولا يطبّق إعدادات.',
                style: TextStyle(color: NovaColors.muted)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Metric(label: 'فحوصات', value: '${_findings.length}', color: NovaColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: _Metric(label: 'تحذيرات', value: '$warning', color: NovaColors.warn)),
                const SizedBox(width: 8),
                Expanded(child: _Metric(label: 'حرج', value: '$critical', color: NovaColors.danger)),
              ]),
              if (_lastRun != null) ...[
                const SizedBox(height: 10),
                Text('آخر فحص: ${_lastRun!.toLocal().toString().substring(0, 19)}', style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _loading ? null : _runAudit,
                icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar_rounded),
                label: Text(_loading ? 'جارٍ الفحص...' : 'تشغيل التدقيق الآن'),
              )),
            ])),
            if (_error != null) ...[
              const SizedBox(height: 12),
              GlassCard(child: Text(_error!, style: const TextStyle(color: NovaColors.danger))),
            ],
            const SizedBox(height: 12),
            if (_findings.isEmpty && !_loading && _error == null)
              const GlassCard(child: Text('ستظهر النتائج هنا بعد بدء الفحص.')),
            for (final finding in _findings) ...[
              const SizedBox(height: 8),
              GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_icon(finding.level), color: _color(finding.level), size: 25),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(finding.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(finding.detail, style: const TextStyle(color: NovaColors.muted)),
                ])),
                const SizedBox(width: 8),
                _Pill(_label(finding.level), finding.level),
              ])),
            ],
            const SizedBox(height: 20),
            const Text('النتائج مؤشرات أولية وليست حكماً نهائياً على الشبكة. قد تختلف البيانات المتاحة حسب إصدار RouterOS وصلاحيات الحساب.',
              style: TextStyle(color: NovaColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  static String _label(_Level level) => switch (level) {
    _Level.ok => 'سليم', _Level.info => 'معلومة', _Level.warning => 'تحذير', _Level.critical => 'حرج',
  };
  static IconData _icon(_Level level) => switch (level) {
    _Level.ok => Icons.check_circle_rounded, _Level.info => Icons.info_outline_rounded,
    _Level.warning => Icons.warning_amber_rounded, _Level.critical => Icons.error_rounded,
  };
  static Color _color(_Level level) => switch (level) {
    _Level.ok => NovaColors.success, _Level.info => NovaColors.primary,
    _Level.warning => NovaColors.warn, _Level.critical => NovaColors.danger,
  };
}

enum _Level { ok, info, warning, critical }

class _AuditFinding {
  final String title;
  final String detail;
  final _Level level;
  const _AuditFinding(this.title, this.detail, this.level);
}

class _Pill extends StatelessWidget {
  final String text;
  final _Level level;
  const _Pill(this.text, this.level);
  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      _Level.ok => NovaColors.success, _Level.info => NovaColors.primary,
      _Level.warning => NovaColors.warn, _Level.critical => NovaColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(30)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: NovaColors.surface2, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: NovaColors.muted)),
    ]),
  );
}
