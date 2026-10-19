import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class _WanLine {
  _WanLine({this.interfaceName}) : gateway = TextEditingController();
  String? interfaceName;
  final TextEditingController gateway;
  void dispose() => gateway.dispose();
}

class LoadBalanceWizardScreen extends ConsumerStatefulWidget {
  const LoadBalanceWizardScreen({super.key});

  @override
  ConsumerState<LoadBalanceWizardScreen> createState() => _LoadBalanceWizardScreenState();
}

class _LoadBalanceWizardScreenState extends ConsumerState<LoadBalanceWizardScreen> {
  final _lanList = TextEditingController(text: 'LAN');
  final List<_WanLine> _lines = [_WanLine(), _WanLine()];
  List<InterfaceInfo> _interfaces = [];
  bool _loading = true;
  bool _applying = false;
  bool _backupVerified = false;
  bool _rollbackReady = false;
  String? _error;
  String? _result;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _lanList.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(mikrotikProvider);
      if (!service.isConnected) throw Exception('اتصل بالراوتر أولاً.');
      final interfaces = await service.interfaces();
      if (!mounted) return;
      setState(() {
        _interfaces = interfaces;
        for (var i = 0; i < _lines.length; i++) {
          if (_lines[i].interfaceName == null && interfaces.isNotEmpty) {
            _lines[i].interfaceName = interfaces[i % interfaces.length].name;
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _addLine() {
    if (_lines.length >= 4) return;
    setState(() {
      final used = _lines.map((e) => e.interfaceName).whereType<String>().toSet();
      final candidates = _interfaces.where((i) => !used.contains(i.name)).toList();
      _lines.add(_WanLine(interfaceName: candidates.isEmpty ? null : candidates.first.name));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 2) return;
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  Future<void> _apply() async {
    if (!_backupVerified || !_rollbackReady) {
      setState(() => _error = 'أكد وجود نسخة احتياطية وخطة تراجع قبل التطبيق.');
      return;
    }
    final lines = _lines.map((line) => <String, String>{
      'interface': line.interfaceName ?? '',
      'gateway': line.gateway.text.trim(),
    }).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد برمجة الدمج الحقيقي'),
        content: const SingleChildScrollView(
          child: Text(
            'سيضيف المعالج جداول توجيه وقواعد PCC ومسارات احتياطية وقواعد NAT بأسماء SAIFLB-WIZARD. قد تتأثر الجلسات الحالية أثناء تبديل المسارات. لن يحذف أو يستبدل قواعدك الحالية، وسيرفض التطبيق إذا اكتشف قواعد Mangle فعّالة لتوجيه الاتصالات. استخدمه فقط على إعداد نظيف ومفهوم، ومن اتصال إدارة محلي.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أوافق وأطبق')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _applying = true;
      _error = null;
      _result = null;
    });
    try {
      await ref.read(mikrotikProvider).applyPccLoadBalance(
        wanLines: lines,
        lanListName: _lanList.text.trim(),
        explicitlyConfirmed: true,
        backupVerified: _backupVerified,
        rollbackPlanAvailable: _rollbackReady,
      );
      if (!mounted) return;
      setState(() {
        _result = 'أرسل التطبيق بنجاح. راجع Routes وMangle وNAT على الراوتر واختبر انقطاع كل خط فعلياً قبل اعتماد الشبكة.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهندس دمج الخطوط'),
        actions: [
          IconButton(
            onPressed: _loading || _applying ? null : _loadInterfaces,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الواجهات',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.alt_route_rounded, color: Colors.white, size: 34),
                      SizedBox(height: 10),
                      Text('Load Balancing Wizard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('PCC لتوزيع الاتصالات الجديدة + Failover بمسارات احتياطية وفحص البوابة ping.', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. واجهة الشبكة الداخلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lanList,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'اسم Interface List للـ LAN',
                            hintText: 'LAN',
                            helperText: 'يجب أن تكون القائمة موجودة وبداخلها واجهات المشتركين.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('2. خطوط الإنترنت', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                    Text('${_lines.length}/4'),
                    IconButton(
                      onPressed: _lines.length >= 4 ? null : _addLine,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      tooltip: 'إضافة خط',
                    ),
                  ],
                ),
                ...List.generate(_lines.length, (index) {
                  final line = _lines[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('الخط ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              if (_lines.length > 2)
                                IconButton(onPressed: () => _removeLine(index), icon: const Icon(Icons.delete_outline_rounded)),
                            ],
                          ),
                          DropdownButtonFormField<String>(
                            value: _interfaces.any((i) => i.name == line.interfaceName) ? line.interfaceName : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'واجهة WAN'),
                            items: _interfaces.map((iface) => DropdownMenuItem(
                              value: iface.name,
                              child: Text('${iface.name} • ${iface.type}', overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (value) => setState(() => line.interfaceName = value),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: line.gateway,
                            textDirection: TextDirection.ltr,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'عنوان بوابة الخط IPv4',
                              hintText: 'مثال: 192.168.1.1',
                              helperText: 'اكتب بوابة هذا الخط الفعلية؛ لا تكتب عنوان DNS مثل 8.8.8.8.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Card(
                  color: AppColors.warning.withOpacity(.08),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'تنبيه مهم: لا يدمج PCC سرعة اتصال واحد؛ يوزّع اتصالات المشتركين بين الخطوط. هذا المعالج مخصص لإعداد نظيف، ويوقف نفسه إذا اكتشف قواعد Mangle فعّالة حتى لا يخرب PCC الحالي أو إعداداتك. يتطلب RouterOS v7 وREST API، والبوابات الثابتة التي تدخلها يجب أن تكون صحيحة وقابلة للوصول.',
                      style: TextStyle(color: AppColors.warning, height: 1.45),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _backupVerified,
                  onChanged: _applying ? null : (v) => setState(() => _backupVerified = v ?? false),
                  title: const Text('تحققت بنفسي من نسخة احتياطية حديثة قابلة للاستعادة'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rollbackReady,
                  onChanged: _applying ? null : (v) => setState(() => _rollbackReady = v ?? false),
                  title: const Text('لدي خطة تراجع واتصال إدارة محلي إذا انقطع الإنترنت'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null)
                  Card(color: AppColors.danger.withOpacity(.12), child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  )),
                if (_result != null)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_result!, style: const TextStyle(color: AppColors.success)),
                  )),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _applying || _interfaces.isEmpty ? null : _apply,
                  icon: _applying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(_applying ? 'جارٍ التحقق والبرمجة…' : 'فحص ثم تطبيق الدمج وFailover'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ملاحظة توافق: لا يوجد تطبيق على RouterOS v6 عبر Binary API في هذا المعالج. لم يتم اختبار هذا الإعداد على راوتر فعلي؛ بعد التطبيق يجب التحقق من المسارات وقواعد الجدار الناري ومراقبة الخطوط.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
