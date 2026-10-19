import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mikrotik_service.dart';
import '../theme.dart';

class LoadBalancingWizardScreen extends ConsumerStatefulWidget {
  const LoadBalancingWizardScreen({super.key});

  @override
  ConsumerState<LoadBalancingWizardScreen> createState() => _LoadBalancingWizardScreenState();
}

class _WanDraft {
  _WanDraft({this.interfaceName = '', this.gateway = ''})
      : gatewayController = TextEditingController(text: gateway);
  String interfaceName;
  final TextEditingController gatewayController;
  String get gateway => gatewayController.text.trim();
  void dispose() => gatewayController.dispose();
}

class _LoadBalancingWizardScreenState extends ConsumerState<LoadBalancingWizardScreen> {
  final _lanController = TextEditingController();
  List<InterfaceInfo> _interfaces = [];
  List<_WanDraft> _wans = [_WanDraft(), _WanDraft()];
  Map<String, List<Map<String, String>>>? _audit;
  bool _loading = true;
  bool _applying = false;
  String? _error;
  bool _backup = false;
  bool _rollback = false;
  bool _confirmed = false;
  int _mode = 0; // PCC with ordered route failover.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lanController.dispose();
    for (final wan in _wans) { wan.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(mikrotikProvider);
      final interfaces = await service.interfaces();
      Map<String, List<Map<String, String>>>? audit;
      try { audit = await service.loadBalancingAudit(); } catch (_) { audit = null; }
      if (!mounted) return;
      setState(() {
        _interfaces = interfaces.where((i) => !i.disabled).toList();
        _audit = audit;
        _loading = false;
        if (_lanController.text.isEmpty) {
          final bridge = _interfaces.where((i) => i.name.toLowerCase().contains('bridge')).firstOrNull;
          _lanController.text = bridge?.name ?? '';
        }
        for (var i = 0; i < _wans.length; i++) {
          if (_wans[i].interfaceName.isEmpty) {
            final candidates = _interfaces.where((it) => it.name.toLowerCase().startsWith('ether') && it.name != _lanController.text).toList();
            if (i < candidates.length) _wans[i].interfaceName = candidates[i].name;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _setCount(int count) {
    setState(() {
      while (_wans.length < count) { _wans.add(_WanDraft()); }
      while (_wans.length > count) { _wans.removeLast().dispose(); }
      for (var i = 0; i < _wans.length; i++) {
        if (_wans[i].interfaceName.isEmpty) {
          final available = _interfaces.where((it) => it.name != _lanController.text && !_wans.any((w) => w != _wans[i] && w.interfaceName == it.name)).toList();
          if (available.isNotEmpty) _wans[i].interfaceName = available.first.name;
        }
      }
    });
  }

  bool get _hasConflicts {
    final rules = _audit?['mangle'] ?? [];
    return rules.any((r) {
      final action = (r['action'] ?? '').toLowerCase();
      return action == 'mark-routing' || action == 'mark-connection';
    });
  }

  List<Map<String, String>> get _plan => _wans.map((w) => {'interface': w.interfaceName, 'gateway': w.gateway}).toList();

  Future<void> _apply() async {
    if (_lanController.text.trim().isEmpty || _wans.any((w) => w.interfaceName.isEmpty || w.gateway.isEmpty)) {
      _message('حدد واجهة LAN وواجهة وبوابة لكل خط.', error: true);
      return;
    }
    if (_wans.map((w) => w.interfaceName).toSet().length != _wans.length ||
        _wans.any((w) => w.interfaceName == _lanController.text.trim())) {
      _message('يجب أن تكون واجهات WAN مختلفة عن بعضها وعن واجهة LAN.', error: true);
      return;
    }
    if (_hasConflicts) {
      _message('تم إيقاف التطبيق لأن الراوتر يحتوي قواعد توجيه Mangle قائمة. لن نضيف PCC فوقها.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('تأكيد تطبيق الدمج'),
        content: const Text('سيضيف التطبيق جداول توجيه وقواعد PCC ومسارات افتراضية بترتيب أولوية مع check-gateway=ping. قد يؤثر ذلك في الإنترنت. لا يُستبدل أي إعداد موجود، ويُرفض التطبيق إذا ظهرت قواعد Mangle متعارضة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أوافق، تابع')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _applying = true);
    try {
      await ref.read(mikrotikProvider).applyLoadBalancingPlan(
        wans: _plan,
        lanInterface: _lanController.text.trim(),
        explicitlyConfirmed: _confirmed,
        backupVerified: _backup,
        rollbackPlanAvailable: _rollback,
      );
      if (!mounted) return;
      _message('أُرسلت إعدادات الدمج للراوتر. افحص الجلسات والإنترنت من شبكة اختبار قبل اعتمادها لكل المشتركين.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _message(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final choices = _interfaces.map((i) => i.name).toSet().toList()..sort();
    final rules = _audit?['mangle'] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهندس دمج الخطوط'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'فحص الراوتر')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.warning),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                ])))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x226366F1)),
                      ),
                      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.hub_rounded, color: Color(0xFFA5B4FC), size: 32),
                        SizedBox(height: 10),
                        Text('PCC + Failover', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text('توزيع اتصالات المشتركين على عدة خطوط، مع مسارات بديلة عند فشل البوابة. الدمج لا يجمع سرعة كل اتصال منفرد في اتصال واحد.', style: TextStyle(color: AppColors.textSecondary, height: 1.45)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('١ · عدد خطوط الإنترنت'),
                    Wrap(spacing: 8, children: List.generate(5, (i) {
                      final count = i + 2;
                      return ChoiceChip(
                        label: Text('$count خطوط'),
                        selected: _wans.length == count,
                        onSelected: (_) => _setCount(count),
                      );
                    })),
                    const SizedBox(height: 18),
                    _sectionTitle('٢ · واجهة الشبكة الداخلية LAN'),
                    DropdownButtonFormField<String>(
                      value: choices.contains(_lanController.text) ? _lanController.text : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bridge / LAN interface'),
                      items: choices.map((name) => DropdownMenuItem(value: name, child: Text(name, textDirection: TextDirection.ltr))).toList(),
                      onChanged: (v) => setState(() => _lanController.text = v ?? ''),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('٣ · إعداد كل خط وبوابته'),
                    ...List.generate(_wans.length, (i) => _wanCard(i, choices)),
                    const SizedBox(height: 16),
                    _sectionTitle('٤ · فحص التعارضات'),
                    _audit == null
                        ? _notice('تعذّر قراءة Mangle والجداول والمسارات. تأكد من REST API وصلاحيات القراءة قبل التطبيق.', warning: true)
                        : _hasConflicts
                            ? _notice('تحذير: وجدنا ${rules.where((r) => ['mark-routing', 'mark-connection'].contains((r['action'] ?? '').toLowerCase())).length} قاعدة Mangle من نوع mark-routing/mark-connection. بسبب احتمال وجود PCC حالي، التطبيق الآلي محظور حتى لا تتعطل الشبكة.', warning: true)
                            : _notice('لم تظهر قواعد Mangle من نوع mark-routing/mark-connection في الفحص الحالي. هذا فحص أولي وليس ضمانًا بعدم وجود تعارضات أخرى.', warning: false),
                    const SizedBox(height: 18),
                    _sectionTitle('٥ · مراجعة الخطة'),
                    _planCard(),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: _backup,
                      onChanged: (v) => setState(() => _backup = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('أخذت نسخة احتياطية حديثة من الراوتر'),
                    ),
                    CheckboxListTile(
                      value: _rollback,
                      onChanged: (v) => setState(() => _rollback = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('لدي خطة تراجع ويمكنني الوصول للراوتر محليًا'),
                    ),
                    CheckboxListTile(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('أوافق صراحةً على تعديل إعدادات الراوتر الحقيقي'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _applying || !_backup || !_rollback || !_confirmed || _hasConflicts || _audit == null ? null : _apply,
                      icon: _applying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.rocket_launch_rounded),
                      label: Text(_applying ? 'جارٍ التطبيق...' : 'تطبيق الدمج وFailover'),
                    ),
                    const SizedBox(height: 8),
                    const Text('ملاحظة أمان: التطبيق الآلي يرفض إضافة قواعد فوق Mangle موجودة. كما أن قيم Gateway يجب أن تكون صحيحة وثابتة؛ لا تكتب اسم مزوّد الخدمة بدل عنوان البوابة.', style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
                  ],
                ),
    );
  }

  Widget _wanCard(int index, List<String> choices) {
    final wan = _wans[index];
    final available = choices.where((name) => name != _lanController.text && (!_wans.any((other) => other != wan && other.interfaceName == name))).toList();
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, child: Text('${index + 1}')),
            const SizedBox(width: 10),
            Text('خط الإنترنت ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: available.contains(wan.interfaceName) ? wan.interfaceName : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'واجهة WAN'),
            items: available.map((name) => DropdownMenuItem(value: name, child: Text(name, textDirection: TextDirection.ltr))).toList(),
            onChanged: (v) => setState(() => wan.interfaceName = v ?? ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: wan.gatewayController,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Gateway IP', hintText: 'مثال: 192.168.1.1', helperText: 'أدخل عنوان بوابة هذا الخط الذي يمكن الوصول إليه عبره'),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
  );

  Widget _notice(String text, {required bool warning}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (warning ? AppColors.warning : AppColors.success).withOpacity(.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: (warning ? AppColors.warning : AppColors.success).withOpacity(.35)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(warning ? Icons.warning_amber_rounded : Icons.verified_outlined, color: warning ? AppColors.warning : AppColors.success),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
    ]),
  );

  Widget _planCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الآلية: PCC + مسارات بديلة', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ..._wans.asMap().entries.map((entry) {
          final i = entry.key;
          final wan = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.router_rounded, size: 18, color: Color(0xFFA5B4FC)),
              const SizedBox(width: 8),
              Expanded(child: Text('${wan.interfaceName.isEmpty ? 'لم تحدد واجهة' : wan.interfaceName}  →  ${wan.gateway.isEmpty ? 'لم تحدد Gateway' : wan.gateway}', textDirection: TextDirection.ltr)),
              Text('أولوية ${i + 1}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          );
        }),
        const Divider(),
        Text('ستنشأ ${_wans.length} جداول توجيه و${_wans.length * 2} قواعد Mangle، مع مسار أساسي وبدائل لكل جدول.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    );
  }
}
