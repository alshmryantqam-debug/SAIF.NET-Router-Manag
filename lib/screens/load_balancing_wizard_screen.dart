import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../providers/connection_provider.dart';

class LoadBalancingWizardScreen extends StatefulWidget {
  const LoadBalancingWizardScreen({super.key});

  @override
  State<LoadBalancingWizardScreen> createState() => _LoadBalancingWizardScreenState();
}

class _LoadBalancingWizardScreenState extends State<LoadBalancingWizardScreen> {
  final Set<String> _selectedWans = <String>{};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRouterInterfaces();
  }

  Future<void> _loadRouterInterfaces() async {
    try {
      await context.read<ConnectionProvider>().fetchInterfacesAndIps();
      if (!mounted) return;
      final provider = context.read<ConnectionProvider>();
      setState(() {
        _isLoading = false;
        _loadError = provider.errorMessage.isEmpty ? null : provider.errorMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر جلب بيانات الراوتر: $e';
      });
    }
  }

  List<dynamic> _addressesFor(String interfaceName, List<dynamic> addresses) {
    return addresses.where((item) =>
      item is Map && item['interface']?.toString() == interfaceName
    ).toList();
  }

  bool _isPhysicalInterface(dynamic item) {
    if (item is! Map) return false;
    final type = item['type']?.toString().toLowerCase() ?? '';
    return type == 'ether' ||
        type == 'wlan' ||
        type.contains('sfp') ||
        type.contains('wifi');
  }

  String get _generatedPreview {
    if (_selectedWans.isEmpty) {
      return '# اختر منافذ WAN لعرضها هنا.';
    }

    final provider = context.read<ConnectionProvider>();
    final lines = <String>[
      '# Nova - معاينة اكتشاف WAN فقط',
      '# المنافذ المختارة من الراوتر:',
    ];
    for (final name in _selectedWans) {
      final addresses = _addressesFor(name, provider.ipAddresses);
      final addressText = addresses.isEmpty
          ? 'لا يوجد عنوان IP مباشر'
          : addresses.map((a) => a['address']?.toString() ?? 'غير معروف').join(', ');
      lines.add('# $name | $addressText');
    }
    lines.addAll([
      '',
      '# لم يتم توليد أو تنفيذ قواعد PCC بعد.',
      '# عنوان IP على المنفذ ليس بالضرورة عنوان البوابة.',
      '# يلزم اكتشاف البوابات الفعلية، منفذ LAN، وجداول التوجيه الحالية',
      '# قبل توليد أوامر تغيّر إعدادات الراوتر بأمان.',
    ]);
    return lines.join('\n');
  }

  void _toggleWan(String interfaceName, bool selected) {
    setState(() {
      if (selected) {
        _selectedWans.add(interfaceName);
      } else {
        _selectedWans.remove(interfaceName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final wanInterfaces = provider.interfaces.where(_isPhysicalInterface).toList()
      ..sort((a, b) => (a['name']?.toString() ?? '')
          .compareTo(b['name']?.toString() ?? ''));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('مهندس دمج الخطوط (ذكي)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تحديث بيانات الراوتر',
            onPressed: _isLoading ? null : () {
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
              _loadRouterInterfaces();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(color: AppTheme.dangerRed),
                    ),
                  ),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'منافذ الشبكة المكتشفة من الراوتر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (wanInterfaces.isEmpty)
                        const Text(
                          'لم يتم العثور على منافذ فعلية. تأكد من الاتصال وصلاحيات REST.',
                          style: TextStyle(color: AppTheme.dangerRed),
                        ),
                      ...wanInterfaces.map((intf) {
                        final name = intf['name']?.toString() ?? '';
                        final addresses = _addressesFor(name, provider.ipAddresses);
                        final ipText = addresses.isEmpty
                            ? 'لا يوجد IP مباشر — قد يستخدم المنفذ DHCP أو يكون ضمن bridge'
                            : addresses.map((a) => a['address']?.toString() ?? '').join(', ');
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$ipText\nالحالة: ${intf['running'] == true ? 'يعمل' : 'غير نشط'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          value: _selectedWans.contains(name),
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (value) => _toggleWan(name, value ?? false),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'معاينة الاكتشاف',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    _generatedPreview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.successGreen,
                      fontSize: 11,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'حماية الراوتر: هذه النسخة تكتشف المنافذ والعناوين فقط. لا يمكن استنتاج البوابة من عنوان IP وحده، كما أن توليد PCC يحتاج معرفة واجهة LAN وجداول التوجيه وقواعد mangle الموجودة. لذلك التنفيذ معطّل هنا حتى لا نضيف قواعد غير صحيحة إلى شبكة الإنتاج.',
                  style: TextStyle(
                    color: AppTheme.warningOrange,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 55,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text(
                      'التنفيذ غير متاح قبل فحص البوابات وPCC',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      disabledBackgroundColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
