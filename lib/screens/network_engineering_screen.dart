import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class NetworkEngineeringScreen extends ConsumerStatefulWidget {
  const NetworkEngineeringScreen({super.key});

  @override
  ConsumerState<NetworkEngineeringScreen> createState() => _NetworkEngineeringScreenState();
}

class _NetworkEngineeringScreenState extends ConsumerState<NetworkEngineeringScreen> {
  final _wanNames = <TextEditingController>[
    TextEditingController(text: 'ether1'),
    TextEditingController(text: 'ether2'),
  ];
  final _gateways = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final _lan = TextEditingController(text: 'bridge');
  final _remoteUrl = TextEditingController();
  final _remoteName = TextEditingController(text: 'NanoStation / Sector');
  final _threshold = TextEditingController(text: '-78');
  int _wanCount = 2;
  bool _discovering = false;
  List<InterfaceInfo> _interfaces = [];
  String _plan = '';
  String? _error;

  @override
  void dispose() {
    for (final c in _wanNames) { c.dispose(); }
    for (final c in _gateways) { c.dispose(); }
    _lan.dispose();
    _remoteUrl.dispose();
    _remoteName.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    final service = ref.read(mikrotikProvider);
    if (!service.isConnected) {
      setState(() => _error = 'اتصل بالراوتر أولاً حتى نقرأ أسماء الواجهات الفعلية.');
      return;
    }
    setState(() { _discovering = true; _error = null; });
    try {
      final rows = await service.interfaces();
      if (!mounted) return;
      setState(() {
        _interfaces = rows;
        for (var i = 0; i < _wanCount; i++) {
          if (i < rows.length && _wanNames[i].text.trim().isEmpty) {
            _wanNames[i].text = rows[i].name;
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة الواجهات: $e');
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  void _changeWanCount(int value) {
    setState(() {
      _wanCount = value;
      while (_wanNames.length < value) {
        _wanNames.add(TextEditingController(text: 'ether${_wanNames.length + 1}'));
        _gateways.add(TextEditingController());
      }
      _plan = '';
    });
  }

  void _buildPlan() {
    final names = _wanNames.take(_wanCount).map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty) || names.toSet().length != names.length) {
      setState(() => _error = 'أدخل اسمًا مختلفًا لكل خط WAN.');
      return;
    }
    final lan = _lan.text.trim();
    if (lan.isEmpty || names.contains(lan)) {
      setState(() => _error = 'حدد واجهة LAN صحيحة ومختلفة عن واجهات WAN.');
      return;
    }
    final found = _interfaces.map((e) => e.name).toSet();
    final unknown = names.where((n) => _interfaces.isNotEmpty && !found.contains(n)).toList();
    if (unknown.isNotEmpty) {
      setState(() => _error = 'واجهات غير موجودة على الراوتر: ${unknown.join(', ')}. أعد الفحص واستخدم الأسماء الفعلية.');
      return;
    }

    final out = StringBuffer()
      ..writeln('# SAIF.NET Load Balancing Wizard — REVIEW PLAN')
      ..writeln('# RouterOS: ${ref.read(connectionProvider).activeProfile?.version.label ?? 'تحقق من الإصدار'}')
      ..writeln('# WAN count: $_wanCount')
      ..writeln('# WAN interfaces: ${names.join(', ')}')
      ..writeln('# LAN interface: $lan')
      ..writeln('# SAFETY: this is a draft, NOT applied to the router.')
      ..writeln('# Do not paste blindly into a live PCC/Queue/Hotspot router.')
      ..writeln('# 1) Export and binary backup first; save current PCC/mangle/routes.')
      ..writeln('# 2) Identify the gateway and routing table for each WAN.')
      ..writeln('# 3) Build per-WAN health checks and failover routes.')
      ..writeln('# 4) Integrate PCC connection marks with existing mangle order.')
      ..writeln('# 5) Verify NAT, DNS, Hotspot, PPPoE, queues and return routing.')
      ..writeln('# 6) Apply during maintenance window with console rollback access.')
      ..writeln('')
      ..writeln('# Proposed link inventory:');
    for (var i = 0; i < names.length; i++) {
      final gw = _gateways[i].text.trim();
      out.writeln('# WAN${i + 1}: interface=${names[i]} gateway=${gw.isEmpty ? '[ENTER_GATEWAY]' : gw}');
    }
    out.writeln('# Gateway-specific PCC/failover commands intentionally withheld until gateways and current routes are verified.');
    setState(() { _plan = out.toString(); _error = null; });
  }

  Future<void> _openRemote() async {
    final raw = _remoteUrl.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      setState(() => _error = 'أدخل رابطًا كاملًا يبدأ بـ https:// أو http://');
      return;
    }
    if (uri.scheme != 'https') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('اتصال غير مشفر'),
          content: const Text('الرابط يستخدم HTTP وقد يكشف بيانات الدخول. لا تفتحه خارج شبكة موثوقة إلا عبر VPN أو نفق آمن. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) setState(() => _error = 'تعذر فتح الرابط على هذا الهاتف.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح الرابط: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('مهندس الشبكة الذكي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.command,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(.35)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.hub_rounded, color: AppColors.primary, size: 32),
              SizedBox(height: 12),
              Text('تحكم هندسي، لا تخمين', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('خطط دمج الخطوط، فحص البنية، والوصول إلى أجهزة البث من مكان واحد. أي تغيير شبكي يجب أن يمر بمراجعة ونسخة احتياطية.', style: TextStyle(color: AppColors.textSecondary, height: 1.55)),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _message(Icons.warning_amber_rounded, _error!, AppColors.warning),
          ],
          const SizedBox(height: 20),
          _section('01', 'مهندس دمج الخطوط', 'PCC + Failover'),
          const SizedBox(height: 10),
          _panel([
            const Text('عدد خطوط الإنترنت', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [2, 3, 4].map((n) => ChoiceChip(
              label: Text('$n خطوط'),
              selected: _wanCount == n,
              onSelected: (_) => _changeWanCount(n),
            )).toList()),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text('قراءة الواجهات من الراوتر', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
              IconButton(onPressed: _discovering ? null : _discover, icon: _discovering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded, color: AppColors.secondary)),
            ]),
            if (_interfaces.isNotEmpty)
              Text('تم العثور على ${_interfaces.length} واجهة. الواجهات العاملة: ${_interfaces.where((e) => e.running && !e.disabled).map((e) => e.name).take(8).join(', ')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 10),
            for (var i = 0; i < _wanCount; i++) ...[
              Row(children: [
                Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Text('W${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 10))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _wanNames[i], decoration: InputDecoration(labelText: 'واجهة WAN ${i + 1}', hintText: 'مثل ether${i + 1}'))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _gateways[i], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'بوابة WAN ${i + 1} (Gateway)', hintText: 'مثال: 192.168.1.1')),
              const SizedBox(height: 12),
            ],
            TextField(controller: _lan, decoration: const InputDecoration(labelText: 'واجهة LAN / Bridge')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _buildPlan, icon: const Icon(Icons.fact_check_rounded), label: const Text('إنشاء خطة الدمج للمراجعة'))),
            if (_plan.isNotEmpty) ...[
              const SizedBox(height: 12),
              _message(Icons.shield_outlined, 'هذه خطة تحضير وليست سكربت تطبيق تلقائي. لم يتم تغيير أي إعداد في الراوتر. يلزم فحص PCC الحالي وبوابات الخطوط لتفادي قطع المشتركين.', AppColors.warning),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: SelectableText(_plan, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary, height: 1.5))),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: _plan)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ خطة المراجعة'))); }, icon: const Icon(Icons.copy_rounded), label: const Text('نسخ الخطة'))),
            ],
          ]),
          const SizedBox(height: 22),
          _section('02', 'فتح صحون البث عن بُعد', 'NanoStation / Sector / Mimosa'),
          const SizedBox(height: 10),
          _panel([
            const Text('افتح لوحة إدارة الجهاز في المتصفح', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('يعمل الرابط من خارج الموقع فقط إذا كان الجهاز متاحًا عبر VPN أو نفق خاص آمن. لا تفتح واجهة الإدارة مباشرة على الإنترنت ولا تعرّض كلمات المرور.', style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5)),
            const SizedBox(height: 12),
            TextField(controller: _remoteName, decoration: const InputDecoration(labelText: 'اسم الجهاز')),
            const SizedBox(height: 10),
            TextField(controller: _remoteUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط الإدارة الآمن', hintText: 'https://device.example أو عنوان VPN')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _openRemote, icon: const Icon(Icons.open_in_browser_rounded), label: const Text('فتح لوحة الجهاز'))),
            const SizedBox(height: 6),
            const Text('ملاحظة: هذا يفتح الرابط في المتصفح الخارجي؛ ليس وسيط Cloud Proxy مستضافًا. إنشاء وسيط سحابي حقيقي يتطلب خادمًا موثوقًا ومصادقة وTLS وسجلات وصول.', style: TextStyle(color: AppColors.warning, fontSize: 10, height: 1.5)),
          ]),
          const SizedBox(height: 22),
          _section('03', 'أدوات مراقبة البرج', 'Power + RF'),
          const SizedBox(height: 10),
          _panel([
            _tool(Icons.bolt_rounded, 'منبه البطاريات والطاقة', 'قراءة الفولتية المتاحة وإرسال إنذار عند الهبوط', () => context.push('/voltage-alarm')),
            const Divider(color: AppColors.border),
            _tool(Icons.radar_rounded, 'رادار صحون البث', 'أجهزة مسجلة وإشارات RF المتاحة عبر MikroTik / SNMP', () => context.push('/radio-radar')),
            const Divider(color: AppColors.border),
            _tool(Icons.router_rounded, 'إدارة الراوترات', 'إدارة ملفات الراوتر والاتصال', () => context.push('/routers')),
          ]),
          const SizedBox(height: 16),
          _message(Icons.info_outline_rounded, connected ? 'الراوتر متصل. اقرأ الواجهات أولاً ثم تحقق يدويًا من أسماء الخطوط والبوابات.' : 'اتصل بالراوتر أولاً لتفعيل اكتشاف الواجهات وبيانات الشبكة.', connected ? AppColors.secondary : AppColors.warning),
        ],
      ),
    );
  }

  Widget _section(String number, String title, String subtitle) => Row(children: [
    Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(11)), child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
      Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ])),
  ]);

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _message(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 19), const SizedBox(width: 9),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11, height: 1.45))),
    ]),
  );

  Widget _tool(IconData icon, String title, String detail, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.1), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary)),
    title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
    subtitle: Text(detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted),
    onTap: onTap,
  );
}
