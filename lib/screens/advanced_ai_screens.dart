import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

const _secure = FlutterSecureStorage();
const _historyKey = 'tikplus.resource.history.v1';
const _rulesKey = 'tikplus.conditional.rules.v1';

class AdvancedAiScreen extends StatelessWidget {
  const AdvancedAiScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgDeep,
    appBar: AppBar(title: const Text('الذكاء والأتمتة المتقدمة'), backgroundColor: AppColors.bgCard),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _tile(context, Icons.mic_rounded, 'المساعد الصوتي', 'أوامر عربية للقراءة من الراوتر', const VoiceAssistantScreen()),
      _tile(context, Icons.query_stats_rounded, 'التحليل التنبؤي', 'اتجاه CPU والذاكرة وسجل القياسات', const PredictiveScreen()),
      _tile(context, Icons.rule_rounded, 'الأتمتة الشرطية', 'قواعد عند انقطاع WAN وتنبيهات داخل التطبيق', const ConditionalAutomationScreen()),
      const _Notice('التوقعات تعتمد فقط على القياسات التي جُمعت وحُفظت أثناء تشغيل التطبيق والاتصال. لا يمكنها استنتاج بيانات الأيام التي لم تكن مراقبة.'),
    ]),
  );
  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Card(color: AppColors.bgCard, child: ListTile(leading: Icon(icon, color: AppColors.primary, size: 28), title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))));
}

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});
  @override ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}
class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false, _listening = false, _busy = false;
  String _heard = '', _answer = 'اضغط الميكروفون وقل: اعرض حالة الراوتر.';
  List<String> _results = [];
  @override void dispose() { _speech.stop(); super.dispose(); }
  Future<void> _listen() async {
    if (!_ready) {
      _ready = await _speech.initialize(onStatus: (s) { if (mounted) setState(() => _listening = s == 'listening'); }, onError: (e) { if (mounted) setState(() => _answer = 'تعذر تشغيل التعرف الصوتي: ' + e.errorMsg); });
    }
    if (!_ready) { setState(() => _answer = 'التعرف الصوتي غير متاح. تحقق من إذن الميكروفون واللغة العربية في الهاتف.'); return; }
    if (_listening) { await _speech.stop(); setState(() => _listening = false); return; }
    await _speech.listen(localeId: 'ar', listenFor: const Duration(seconds: 12), pauseFor: const Duration(seconds: 3), onResult: (r) { if (!mounted) return; setState(() => _heard = r.recognizedWords); if (r.finalResult) _runCommand(r.recognizedWords); });
    setState(() => _listening = true);
  }
  Future<void> _runCommand(String raw) async {
    final q = raw.toLowerCase();
    setState(() { _busy = true; _results = []; _answer = 'أحلل الأمر الصوتي وأقرأ البيانات المطلوبة...'; });
    try {
      final service = ref.read(mikrotikProvider);
      if (!service.isConnected) throw Exception('اتصل بالراوتر أولاً');
      if (q.contains('حالة الراوتر') || q.contains('حاله الراوتر') || q.contains('المعالج') || q.contains('الذاكرة') || q.contains('رام')) {
        final r = await service.systemResource();
        setState(() { _answer = 'حالة الراوتر: CPU ${r.cpuLoad}%، الذاكرة المستخدمة ${r.memUsedPercent.toStringAsFixed(0)}%، مدة التشغيل ${r.uptime}، إصدار RouterOS ${r.version}.'; _results = ['CPU: ${r.cpuLoad}%', 'RAM: ${r.memUsedPercent.toStringAsFixed(0)}%', 'Uptime: ${r.uptime}', 'RouterOS: ${r.version}']; });
      } else if (q.contains('واجهة') || q.contains('wan') || q.contains('منافذ')) {
        final list = await service.interfaces();
        final rows = list.map((i) => '${i.name}: ${i.disabled ? "معطّل" : i.running ? "يعمل" : "متوقف"}').toList();
        setState(() { _answer = rows.isEmpty ? 'لم تُرجع الواجهة أي بيانات.' : 'حالة الواجهات: ' + rows.join('؛ '); _results = rows; });
      } else if (q.contains('dhcp') || q.contains('أجهزة') || q.contains('اجهزة') || q.contains('عملاء')) {
        final list = await service.dhcpLeases();
        final rows = list.take(30).map((d) => '${d.hostName.isEmpty ? "جهاز" : d.hostName} · ${d.address} · ${d.isBound ? "مرتبط" : d.status}').toList();
        setState(() { _answer = 'عدد سجلات DHCP: ${list.length}.'; _results = rows; });
      } else {
        setState(() { _answer = 'لم أفهم الأمر بأمان. جرّب: اعرض حالة الراوتر، اعرض حالة الواجهات، أو اعرض أجهزة DHCP. لا أنفّذ أوامر تغيير الإعدادات صوتياً.'; });
      }
    } catch (e) { setState(() => _answer = 'تعذر تنفيذ الاستعلام للقراءة فقط: ' + e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(backgroundColor: AppColors.bgDeep, appBar: AppBar(title: const Text('المساعد الصوتي'), backgroundColor: AppColors.bgCard),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _Notice('الأوامر الصوتية تتحول إلى استعلامات قراءة محددة وآمنة فقط. لا يوجد تنفيذ صوتي لأوامر تعطيل المستخدمين أو تغيير الجدار الناري أو المسارات.'),
        const SizedBox(height: 20),
        Center(child: InkWell(onTap: _busy ? null : _listen, borderRadius: BorderRadius.circular(100), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 116, height: 116, decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.primary, boxShadow: AppShadows.glow(AppColors.primary, opacity: _listening ? .55 : .18)), child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 48)))),
        const SizedBox(height: 12),
        Center(child: Text(_listening ? 'أستمع الآن…' : 'اضغط للتحدث بالعربية', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
        if (!connected) const _Notice('لا يوجد اتصال بالراوتر. اتصل أولاً ثم أعد المحاولة.'),
        const SizedBox(height: 18),
        _panel('ما سمعه التطبيق', Text(_heard.isEmpty ? '—' : _heard, style: const TextStyle(color: AppColors.textPrimary))),
        _panel('النتيجة', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (_busy) const LinearProgressIndicator(), Text(_answer, style: const TextStyle(color: AppColors.textPrimary, height: 1.5)), ..._results.map((s) => Padding(padding: const EdgeInsets.only(top: 7), child: Text(s, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))))])),
        const Text('أمثلة: «اعرض حالة الراوتر» · «اعرض حالة الواجهات» · «اعرض أجهزة DHCP»', style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5)),
      ]));
  }
}

class PredictiveScreen extends ConsumerStatefulWidget {
  const PredictiveScreen({super.key});
  @override ConsumerState<PredictiveScreen> createState() => _PredictiveScreenState();
}
class _PredictiveScreenState extends ConsumerState<PredictiveScreen> {
  List<_Sample> _samples = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final raw = await _secure.read(key: _historyKey);
    final rows = <_Sample>[];
    if (raw != null) { try { for (final x in (jsonDecode(raw) as List)) { final s = _Sample.fromJson(Map<String, dynamic>.from(x)); if (DateTime.now().difference(s.time) <= const Duration(days: 7)) rows.add(s); } } catch (_) {} }
    if (mounted) setState(() { _samples = rows; _loading = false; });
  }
  Future<void> _collect() async {
    try {
      final service = ref.read(mikrotikProvider);
      if (!service.isConnected) throw Exception('اتصل بالراوتر لجمع قياس جديد');
      final r = await service.systemResource();
      final now = DateTime.now();
      _samples.removeWhere((s) => now.difference(s.time) > const Duration(days: 7));
      _samples.add(_Sample(now, r.cpuLoad.toDouble(), r.memUsedPercent));
      await _secure.write(key: _historyKey, value: jsonEncode(_samples.map((s) => s.toJson()).toList()));
      if (mounted) setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ قياس جديد ضمن سجل الأيام السبعة')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  _Trend _trend(bool cpu) {
    if (_samples.length < 3) return _Trend('بيانات غير كافية', 'اجمع 3 قياسات على الأقل في أوقات مختلفة؛ الأفضل مراقبة مستمرة على مدار 7 أيام.', AppColors.textMuted);
    final sorted = [..._samples]..sort((a,b)=>a.time.compareTo(b.time));
    final vals = sorted.map((s)=>cpu?s.cpu:s.ram).toList();
    final n = vals.length; final early = vals.take((n/3).ceil()).toList(); final late = vals.skip((n*2/3).floor()).toList();
    final first = early.reduce((a,b)=>a+b)/early.length; final last = late.reduce((a,b)=>a+b)/late.length; final latest = vals.last;
    if (latest >= (cpu ? 90 : 92) || (last-first >= 15 && last >= (cpu ? 70 : 75))) return _Trend('خطر مرتفع', 'المتوسط ارتفع ${(last-first).toStringAsFixed(1)} نقطة، والقراءة الأخيرة ${latest.toStringAsFixed(0)}%. افحص العمليات والاتصالات والموارد.', AppColors.danger);
    if (last-first >= 7 || latest >= (cpu ? 80 : 85)) return _Trend('تنبيه مراقبة', 'هناك ارتفاع ملحوظ أو مستوى استخدام مرتفع. هذا مؤشر ضغط وليس توقعاً مؤكداً للتعطل.', AppColors.warning);
    return _Trend('لا يوجد اتجاه تصاعدي واضح', 'القياسات المتاحة لا تظهر ارتفاعاً تدريجياً حاداً. قلة العينات تقلل موثوقية النتيجة.', AppColors.success);
  }
  @override Widget build(BuildContext context) {
    final cpu = _trend(true), ram = _trend(false);
    return Scaffold(backgroundColor: AppColors.bgDeep, appBar: AppBar(title: const Text('التحليل التنبؤي'), backgroundColor: AppColors.bgCard, actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _Notice('لا يمكن إنشاء سجل تاريخي بأثر رجعي. هذه الشاشة تحلل القياسات التي حفظها التطبيق فقط خلال آخر 7 أيام؛ لا تُعدّ التوقعات ضماناً للتعطل أو السلامة.'),
        const SizedBox(height: 10), FilledButton.icon(onPressed: _collect, icon: const Icon(Icons.add_chart), label: const Text('جمع قياس الآن')),
        if (_loading) const LinearProgressIndicator(),
        _trendCard('المعالج CPU', cpu, _samples.length),
        _trendCard('الذاكرة RAM', ram, _samples.length),
        _panel('آخر القياسات', Column(children: _samples.reversed.take(12).map((s)=>ListTile(dense:true, contentPadding:EdgeInsets.zero, title:Text('${s.cpu.toStringAsFixed(0)}% CPU · ${s.ram.toStringAsFixed(0)}% RAM',style:const TextStyle(color:AppColors.textPrimary)), subtitle:Text(s.time.toLocal().toString().substring(0,16),style:const TextStyle(color:AppColors.textMuted,fontSize:11))).toList())),
      ]));
  }
  Widget _trendCard(String title, _Trend trend, int count) => _panel(title, Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Row(children:[Icon(Icons.circle,size:10,color:trend.color),const SizedBox(width:8),Text(trend.title,style:TextStyle(color:trend.color,fontWeight:FontWeight.bold))]),const SizedBox(height:8),Text(trend.detail,style:const TextStyle(color:AppColors.textSecondary,height:1.5,fontSize:12)),const SizedBox(height:6),Text('عدد العينات: $count',style:const TextStyle(color:AppColors.textMuted,fontSize:10))]));
}

class ConditionalAutomationScreen extends ConsumerStatefulWidget {
  const ConditionalAutomationScreen({super.key});
  @override ConsumerState<ConditionalAutomationScreen> createState() => _ConditionalAutomationScreenState();
}
class _ConditionalAutomationScreenState extends ConsumerState<ConditionalAutomationScreen> {
  List<Map<String,dynamic>> _rules = [];
  Timer? _timer;
  bool _checking = false;
  final Set<String> _alreadyAlerted = {};
  @override void initState() { super.initState(); _load(); _timer=Timer.periodic(const Duration(seconds:30), (_) => _check()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  Future<void> _load() async { final raw=await _secure.read(key:_rulesKey); if(raw!=null){try{final list=(jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e)).toList();if(mounted)setState(()=>_rules=list);}catch(_){}} }
  Future<void> _save() async => _secure.write(key:_rulesKey,value:jsonEncode(_rules));
  Future<void> _addRule() async {
    final name=TextEditingController(text:'تنبيه عند انقطاع WAN');
    final selected=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة قاعدة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم القاعدة')),const SizedBox(height:10),const Text('الشرط: واجهة WAN متوقفة\nالإجراء: تنبيه داخل التطبيق',style:TextStyle(height:1.6))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,name.text.trim().isEmpty?'تنبيه WAN':name.text.trim()),child:const Text('إضافة'))]));
    name.dispose(); if(selected==null)return;
    setState(()=>_rules.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':selected,'enabled':true,'condition':'wan_down','action':'in_app_alert'})); await _save();
  }
  Future<void> _check() async {
    if(_checking||!mounted||!ref.read(connectionProvider).isConnected)return;
    final active=_rules.where((r)=>r['enabled']==true).toList();if(active.isEmpty)return;
    _checking=true;
    try {
      ref.invalidate(interfacesProvider);
      final list=await ref.read(interfacesProvider.future);
      for(final rule in active){
        final wan=list.where((i)=>i.name.toLowerCase().contains('wan')||i.name.toLowerCase()=='ether1'||i.name.toLowerCase()=='ether2'||i.name.toLowerCase()=='ether3').toList();
        final down=wan.isNotEmpty&&wan.every((i)=>!i.running||i.disabled);
        final id=rule['id'] as String;
        if(down&&!_alreadyAlerted.contains(id)){
          _alreadyAlerted.add(id);
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration:const Duration(seconds:8),content:Text('تنبيه أتمتة: ${rule['name']} — واجهات WAN المكتشفة متوقفة.')));
        } else if(!down) _alreadyAlerted.remove(id);
      }
    }catch(_){}
    finally{_checking=false;}
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:AppColors.bgDeep,appBar:AppBar(title:const Text('الأتمتة الشرطية'),backgroundColor:AppColors.bgCard,actions:[IconButton(onPressed:_check,icon:const Icon(Icons.play_arrow_rounded))]),
    floatingActionButton:FloatingActionButton.extended(onPressed:_addRule,icon:const Icon(Icons.add),label:const Text('إضافة قاعدة')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const _Notice('القواعد تُفحص كل 30 ثانية أثناء بقاء هذه الشاشة مفتوحة والتطبيق متصلاً. التنبيه داخل التطبيق فقط؛ إشعارات الخلفية تحتاج خدمة خلفية وصلاحيات نظام إضافية. أسماء WAN الافتراضية تشمل ether1/ether2/ether3 أو واجهة يحتوي اسمها WAN.'),
      const SizedBox(height:10),
      if(_rules.isEmpty) const _Notice('لا توجد قواعد بعد. أضف قاعدة «إذا انقطعت WAN فأظهر تنبيهاً».'),
      ..._rules.map((r)=>Card(color:AppColors.bgCard,child:SwitchListTile(value:r['enabled']==true,title:Text(r['name'] as String,style:const TextStyle(color:AppColors.textPrimary,fontWeight:FontWeight.bold)),subtitle:const Text('إذا توقفت كل واجهات WAN المكتشفة ← تنبيه داخل التطبيق'),activeColor:AppColors.primary,onChanged:(v)async{setState(()=>r['enabled']=v);await _save();},secondary:Icon(Icons.notifications_active,color:r['enabled']==true?AppColors.warning:AppColors.textMuted),)),
      ),
      if(_rules.isNotEmpty) OutlinedButton.icon(onPressed:_check,icon:const Icon(Icons.monitor_heart),label:const Text('فحص الشروط الآن')),
    ]));
}

class _Sample {
  const _Sample(this.time,this.cpu,this.ram);
  final DateTime time; final double cpu,ram;
  Map<String,dynamic> toJson()=>{'time':time.toIso8601String(),'cpu':cpu,'ram':ram};
  factory _Sample.fromJson(Map<String,dynamic> j)=>_Sample(DateTime.parse(j['time'] as String),(j['cpu'] as num).toDouble(),(j['ram'] as num).toDouble());
}
class _Trend { const _Trend(this.title,this.detail,this.color); final String title,detail; final Color color; }
class _Notice extends StatelessWidget { const _Notice(this.text); final String text; @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.warning.withOpacity(.08),border:Border.all(color:AppColors.warning.withOpacity(.3)),borderRadius:BorderRadius.circular(12)),child:Text(text,style:const TextStyle(color:AppColors.textSecondary,fontSize:12,height:1.5))); }
Widget _panel(String title,Widget child)=>Container(margin:const EdgeInsets.symmetric(vertical:7),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.bgCard,border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:AppColors.textPrimary,fontWeight:FontWeight.bold)),const SizedBox(height:10),child]));
