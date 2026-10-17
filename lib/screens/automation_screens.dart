import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class AutomationHubScreen extends StatelessWidget {
  const AutomationHubScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgDeep,
    appBar: AppBar(title: const Text('الأتمتة الذكية'), backgroundColor: AppColors.bgCard),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _card(context, Icons.auto_mode, 'التجهيز بدون لمس', 'قالب إعداد أولي للمراجعة', const ZeroTouchScreen()),
      _card(context, Icons.psychology_alt, 'المساعد الذكي', 'تحليل الأعراض واقتراح أوامر فحص', const CopilotScreen()),
      _card(context, Icons.hub, 'خريطة الشبكة', 'عرض الواجهات وأجهزة DHCP وحالتها', const NetworkMapScreen()),
      const _Notice('نسخة أولية: لا توجد خدمة تسجيل آمن للراوترات أو ذكاء اصطناعي سحابي. لا تطبق أي إعداد تلقائياً.'),
    ]),
  );
  Widget _card(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Card(
    color: AppColors.bgCard, child: ListTile(leading: Icon(icon, color: AppColors.primary, size: 28),
    title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
    trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))));
}

class ZeroTouchScreen extends StatefulWidget {
  const ZeroTouchScreen({super.key});
  @override State<ZeroTouchScreen> createState() => _ZeroTouchScreenState();
}
class _ZeroTouchScreenState extends State<ZeroTouchScreen> {
  final identity = TextEditingController(text: 'SAIF-EDGE-01');
  final lan = TextEditingController(text: '192.168.88.1/24');
  final dns = TextEditingController(text: '1.1.1.1,8.8.8.8');
  String template = '';
  @override void dispose() { identity.dispose(); lan.dispose(); dns.dispose(); super.dispose(); }
  void generate() {
    final name = identity.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '');
    final addr = lan.text.trim();
    final servers = dns.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
    if (name.isEmpty || !RegExp(r'^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$').hasMatch(addr) || servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من اسم الراوتر وعنوان LAN وDNS'))); return;
    }
    setState(() => template = '# SAIF.NET ZTP template preview\n# Review interface names before use.\n/system identity set name="' + name + '"\n/ip address add address=' + addr + ' interface=bridge comment="SAIF.NET LAN"\n/ip dns set servers=' + servers + ' allow-remote-requests=no\n# DHCP/WAN/NAT/PCC/queues/hotspot/firewall intentionally untouched.');
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgDeep, appBar: AppBar(title: const Text('التجهيز بدون لمس'), backgroundColor: AppColors.bgCard),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const _Notice('هذا مولّد قالب فقط، وليس Zero-Touch فعلياً. يلزم خادم موثوق وتسجيل آمن للراوتر قبل التوزيع. القالب لا يغيّر WAN أو NAT أو PCC أو Queue أو Hotspot أو Firewall.'),
      const SizedBox(height: 12), _field(identity, 'اسم الراوتر'), const SizedBox(height: 10),
      _field(lan, 'عنوان LAN مع القناع'), const SizedBox(height: 10), _field(dns, 'DNS مفصول بفاصلة'),
      const SizedBox(height: 12), ElevatedButton.icon(onPressed: generate, icon: const Icon(Icons.auto_awesome), label: const Text('إنشاء قالب للمراجعة')),
      if (template.isNotEmpty) ...[const SizedBox(height: 12), SelectableText(template, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace')), ElevatedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: template)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ القالب'))); }, icon: const Icon(Icons.copy), label: const Text('نسخ القالب'))]
    ]));
  Widget _field(TextEditingController c, String label) => TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}

class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});
  @override ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}
class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final question = TextEditingController();
  String answer = 'اكتب المشكلة: بطء، انقطاع، DNS، أو جهاز لا يحصل على IP.';
  List<String> commands = [];
  @override void dispose() { question.dispose(); super.dispose(); }
  void analyze() {
    final q = question.text.toLowerCase();
    if (q.trim().isEmpty) return;
    if (q.contains('بطء') || q.contains('سرعة') || q.contains('slow')) {
      answer = 'حدد موضع الاختناق أولاً: حمل الراوتر، أخطاء WAN، ازدحام Queue، والمسار الافتراضي. لا تغيّر PCC قبل جمع النتائج.';
      commands = ['/system/resource/print', '/interface/print stats', '/queue/simple/print stats', '/ip/route/print detail'];
    } else if (q.contains('انقطاع') || q.contains('يفصل') || q.contains('قطع')) {
      answer = 'قد يكون السبب خط WAN أو DHCP/PPPoE أو طبقة الربط أو المسار. قارن السجل مع وقت الانقطاع وافحص البوابة قبل أي تعديل.';
      commands = ['/log/print', '/interface/print detail', '/ip/dhcp-client/print detail', '/ppp/active/print'];
    } else if (q.contains('dns') || q.contains('واتساب') || q.contains('مواقع')) {
      answer = 'إذا تعطلت بعض التطبيقات فقط، افحص DNS وMTU والمسار الافتراضي وقارن ping إلى IP مع اسم نطاق.';
      commands = ['/ip/dns/print', '/ip/route/print detail', '/ping 1.1.1.1 count=4', '/ping example.com count=4'];
    } else {
      answer = 'الوصف غير كافٍ للجزم بالسبب. اجمع موارد النظام والسجل وحالة الواجهات والمسارات، واحذف أي كلمات مرور قبل مشاركة النتائج.';
      commands = ['/system/resource/print', '/log/print', '/interface/print detail', '/ip/route/print detail'];
    }
    setState(() {});
  }
  @override Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);
    final resource = ref.watch(systemResourceProvider);
    return Scaffold(backgroundColor: AppColors.bgDeep, appBar: AppBar(title: const Text('المساعد الذكي'), backgroundColor: AppColors.bgCard),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _Notice('مساعد تشخيص محلي قائم على قواعد، وليس نموذج AI سحابياً. الأوامر اقتراحات للقراءة فقط ولا تُنفذ تلقائياً.'),
        if (conn.isConnected) resource.when(data: (r) => Text('CPU: ' + r.cpuLoad.toString() + '% · RAM: ' + r.memUsedPercent.round().toString() + '% · Uptime: ' + r.uptime, style: const TextStyle(color: AppColors.success)), loading: () => const LinearProgressIndicator(), error: (_, __) => const Text('تعذر قراءة موارد الراوتر', style: TextStyle(color: AppColors.warning))),
        const SizedBox(height: 12), TextField(controller: question, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'اشرح العطل', border: OutlineInputBorder())),
        const SizedBox(height: 10), ElevatedButton.icon(onPressed: analyze, icon: const Icon(Icons.search), label: const Text('تحليل المشكلة')),
        const SizedBox(height: 16), _panel('التحليل الأولي', Text(answer, style: const TextStyle(color: AppColors.textPrimary, height: 1.5))),
        if (commands.isNotEmpty) _panel('أوامر الفحص المقترحة', Column(crossAxisAlignment: CrossAxisAlignment.start, children: commands.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: SelectableText(c, style: const TextStyle(color: AppColors.primary, fontFamily: 'monospace')))).toList()))
      ]));
  }
}

class NetworkMapScreen extends ConsumerWidget {
  const NetworkMapScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final interfaces = ref.watch(interfacesProvider);
    final leases = ref.watch(dhcpLeasesProvider);
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(backgroundColor: AppColors.bgDeep, appBar: AppBar(title: const Text('خريطة الشبكة'), backgroundColor: AppColors.bgCard, actions: [IconButton(onPressed: () { ref.invalidate(interfacesProvider); ref.invalidate(dhcpLeasesProvider); }, icon: const Icon(Icons.refresh))]),
      body: !connected ? const Center(child: Text('اتصل بالراوتر لعرض بيانات الشبكة', style: TextStyle(color: AppColors.textSecondary))) : RefreshIndicator(onRefresh: () async { ref.invalidate(interfacesProvider); ref.invalidate(dhcpLeasesProvider); },
        child: ListView(padding: const EdgeInsets.all(14), children: [
          _panel('الطوبولوجيا', const Column(children: [
            _Node(icon: Icons.public, title: 'الإنترنت / WAN', detail: 'المنافذ الخارجية'),
            Icon(Icons.south, color: AppColors.textMuted),
            _Node(icon: Icons.router, title: 'راوتر MikroTik', detail: 'الجهاز المتصل'),
            Icon(Icons.south, color: AppColors.textMuted),
            _Node(icon: Icons.hub, title: 'LAN / Bridge / العملاء', detail: 'الواجهات وأجهزة DHCP')
          ])),
          interfaces.when(data: (list) => _panel('الواجهات (' + list.length.toString() + ')', list.isEmpty ? const Text('لا توجد بيانات') : Column(children: list.map((i) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(i.running && !i.disabled ? Icons.check_circle : Icons.error_outline, color: i.running && !i.disabled ? AppColors.success : AppColors.warning), title: Text(i.name, style: const TextStyle(color: AppColors.textPrimary)), subtitle: Text(i.type + ' · RX ' + _fmt(i.rxByte) + ' · TX ' + _fmt(i.txByte), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)), trailing: Text(i.disabled ? 'معطّل' : i.running ? 'يعمل' : 'متوقف', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)))).toList())), loading: () => const LinearProgressIndicator(), error: (e, _) => _Notice('تعذر تحميل الواجهات: ' + e.toString())),
          leases.when(data: (list) => _panel('أجهزة DHCP (' + list.length.toString() + ')', list.isEmpty ? const Text('لا توجد أجهزة DHCP ظاهرة', style: TextStyle(color: AppColors.textMuted)) : Column(children: list.map((d) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(d.isBound ? Icons.devices : Icons.device_unknown, color: d.isBound ? AppColors.success : AppColors.warning), title: Text(d.hostName.isEmpty ? 'جهاز بدون اسم' : d.hostName, style: const TextStyle(color: AppColors.textPrimary)), subtitle: Text(d.address + ' · ' + d.mac, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)), trailing: Text(d.isBound ? 'متصل' : (d.status.isEmpty ? 'غير معروف' : d.status), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)))).toList())), loading: () => const LinearProgressIndicator(), error: (e, _) => _Notice('تعذر تحميل أجهزة DHCP: ' + e.toString())),
          const _Notice('تحليل السبب الجذري مبدئي: واجهة WAN متوقفة ← افحص الكابل والمودم وDHCP/المسار. LAN تعمل ولا توجد Lease ← افحص DHCP وBridge/VLAN. الواجهات تعمل والإنترنت متوقف ← افحص المسار الافتراضي وDNS وping. هذه مؤشرات وليست تشخيصاً مؤكداً.')
        ])));
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text); final String text;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withOpacity(.08), border: Border.all(color: AppColors.warning.withOpacity(.3)), borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)));
}
Widget _panel(String title, Widget child) => Container(margin: const EdgeInsets.symmetric(vertical: 7), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.bgCard, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)), const SizedBox(height: 10), child]));
class _Node extends StatelessWidget {
  const _Node({required this.icon, required this.title, required this.detail}); final IconData icon; final String title; final String detail;
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(.08), border: Border.all(color: AppColors.primary.withOpacity(.35)), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)), Text(detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]))]));
}
String _fmt(int n) => n < 1024 ? n.toString() + ' B' : n < 1048576 ? (n / 1024).toStringAsFixed(1) + ' KB' : (n / 1048576).toStringAsFixed(1) + ' MB';
