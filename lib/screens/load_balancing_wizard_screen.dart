import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass_card.dart';
import '../theme.dart';

class LoadBalancingWizardScreen extends StatefulWidget {
  const LoadBalancingWizardScreen({super.key});

  @override
  State<LoadBalancingWizardScreen> createState() =>
      _LoadBalancingWizardScreenState();
}

class _LoadBalancingWizardScreenState
    extends State<LoadBalancingWizardScreen> {
  int _wanCount = 2;
  final TextEditingController _lanController =
      TextEditingController(text: 'bridge');
  List<TextEditingController> _wanControllers = [];
  String _generatedScript = '';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _initWanControllers();
  }

  void _initWanControllers() {
    for (final controller in _wanControllers) {
      controller.dispose();
    }
    _wanControllers = List.generate(
      _wanCount,
      (index) => TextEditingController(text: 'ether${index + 1}'),
    );
  }

  bool _isValidInterfaceName(String name) {
    return name.isNotEmpty &&
        RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(name);
  }

  void _generateScript() {
    final lan = _lanController.text.trim();
    final wanNames = _wanControllers.map((c) => c.text.trim()).toList();

    if (!_isValidInterfaceName(lan)) {
      setState(() {
        _validationError = 'أدخل اسم واجهة LAN صحيحاً.';
        _generatedScript = '';
      });
      return;
    }
    if (wanNames.any((name) => !_isValidInterfaceName(name))) {
      setState(() {
        _validationError = 'تحقق من أسماء جميع منافذ WAN.';
        _generatedScript = '';
      });
      return;
    }
    if (wanNames.toSet().length != wanNames.length ||
        wanNames.contains(lan)) {
      setState(() {
        _validationError = 'يجب أن تكون أسماء المنافذ فريدة وألا تتطابق LAN مع WAN.';
        _generatedScript = '';
      });
      return;
    }

    final script = StringBuffer();
    script.writeln('# ================================================');
    script.writeln('# Nova Dynamic PCC Load Balancing Script ($_wanCount WANs)');
    script.writeln('# RouterOS v7+ - REVIEW BEFORE APPLYING');
    script.writeln('# ================================================\n');
    script.writeln('# IMPORTANT: This is a template, not a complete deployment.');
    script.writeln('# Configure routing tables, gateways/routes, LAN/WAN topology,');
    script.writeln('# existing PCC/mangle rules, and router-originated traffic first.');
    script.writeln('# Do not paste into a production router without reviewing conflicts.\n');

    script.writeln('/ip firewall mangle');
    for (var i = 0; i < _wanCount; i++) {
      final wan = wanNames[i];
      script.writeln(
        'add action=mark-connection chain=prerouting dst-address-type=!local in-interface=$lan new-connection-mark=${wan}_conn passthrough=yes per-connection-classifier=both-addresses-and-ports:$_wanCount/$i comment="Nova PCC - $wan connection"',
      );
      script.writeln(
        'add action=mark-routing chain=prerouting connection-mark=${wan}_conn in-interface=$lan new-routing-mark=to_$wan passthrough=yes comment="Nova PCC - $wan routing"',
      );
    }

    script.writeln('\n/ip firewall nat');
    for (var i = 0; i < _wanCount; i++) {
      final wan = wanNames[i];
      script.writeln(
        'add action=masquerade chain=srcnat out-interface=$wan comment="Nova PCC - NAT $wan"',
      );
    }

    setState(() {
      _validationError = null;
      _generatedScript = script.toString();
    });
  }

  @override
  void dispose() {
    _lanController.dispose();
    for (final controller in _wanControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = (String label, {Widget? prefixIcon}) =>
        InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: prefixIcon,
          filled: true,
          fillColor: AppTheme.backgroundColor.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('معالج دمج الخطوط (PCC)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إعدادات الدمج الأساسية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'عدد خطوط الدخول (WANs):',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _wanCount,
                        dropdownColor: AppTheme.cardColor,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        items: [2, 3, 4, 5, 6]
                            .map((value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _wanCount = value;
                            _initWanControllers();
                            _generatedScript = '';
                            _validationError = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lanController,
                    style: const TextStyle(color: Colors.white),
                    decoration: fieldDecoration('واجهة خروج المشتركين (LAN)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تسمية منافذ الدخول (مثال: ether1, ether2)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    _wanCount,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _wanControllers[index],
                        style: const TextStyle(color: Colors.white),
                        decoration: fieldDecoration(
                          'اسم المنفذ (WAN ${index + 1})',
                          prefixIcon: const Icon(
                            Icons.settings_ethernet,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _validationError!,
                      style: const TextStyle(color: AppTheme.dangerColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _generateScript,
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: const Text(
                        'توليد السكربت',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_generatedScript.isNotEmpty) ...[
              const SizedBox(height: 24),
              GlassCard(
                useGradient: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'السكربت الجاهز للمراجعة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ السكربت',
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _generatedScript),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.successColor,
                                content: Text('تم نسخ السكربت'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    SelectableText(
                      _generatedScript,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'تنبيه: التوليد لا يطبّق الإعدادات على الراوتر. هذا القالب لا ينشئ جداول التوجيه أو المسارات والبوابات المطلوبة لـ RouterOS v7، ولا يفحص قواعد PCC الحالية. راجعها واختبرها قبل التطبيق.',
                style: TextStyle(color: AppTheme.warningColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
