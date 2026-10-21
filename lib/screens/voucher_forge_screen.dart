import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotspot_provider.dart';
import '../widgets/cyber_crypto_forge.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class VoucherForgeScreen extends StatefulWidget {
  const VoucherForgeScreen({Key? key}) : super(key: key);

  @override
  State<VoucherForgeScreen> createState() => _VoucherForgeScreenState();
}

class _VoucherForgeScreenState extends State<VoucherForgeScreen> {
  static const _magenta = Color(0xFFE040FB);
  static const _cyan = Color(0xFF00E5FF);
  static const _green = Color(0xFF4CAE7D);
  static const _red = Color(0xFFFF5252);

  bool _isForging = false;
  double _voucherCount = 100;
  double _codeLength = 6;
  String _selectedProfile = 'default';

  // هذه أسماء ملفات سرعة افتراضية؛ يجب اختيار اسم موجود فعلاً في الراوتر.
  final List<String> _profiles = const [
    'default',
    '1M',
    '2M',
    '5M',
  ];

  Future<void> _startForgingProcess() async {
    if (_isForging) return;
    final provider = context.read<HotspotProvider>();

    if (_selectedProfile.trim().isEmpty) {
      _showMessage('أدخل اسم ملف سرعة صالحاً.', success: false);
      return;
    }

    setState(() => _isForging = true);
    bool success = false;
    try {
      // يستعمل مزود الهوتسبوت الموجود في المشروع ويكتب البطاقات فعلياً
      // عبر اتصال الراوتر الحالي؛ لا توجد محاكاة زمنية لنجاح العملية.
      success = await provider.generateVouchers(
        _voucherCount.toInt(),
        _selectedProfile,
        _codeLength.toInt().toString(),
      );
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _isForging = false);
    _showMessage(
      success
          ? 'اكتمل صك ${_voucherCount.toInt()} بطاقة على الراوتر.'
          : 'تعذر صك البطاقات. تحقق من الاتصال واسم ملف السرعة وصلاحيات الحساب.',
      success: success,
    );
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? _green : _red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotspotProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'ترسانة صك البطاقات',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
              shadows: [Shadow(color: _magenta, blurRadius: 10)],
            ),
          ),
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              physics: const BouncingScrollPhysics(),
              children: [
                NovaTechPanel(
                  accentColor: _isForging ? _magenta : _cyan,
                  child: Column(
                    children: [
                      CyberCryptoForge(isForging: _isForging),
                      const SizedBox(height: 4),
                      Text(
                        _isForging
                            ? 'جارٍ إنشاء البطاقات على الراوتر'
                            : provider.isLoading
                                ? 'المزود ينفذ عملية أخرى'
                                : 'المحرك في وضع الاستعداد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isForging ? _magenta : _cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يُستخدم اتصال الراوتر الحالي؛ لا تُعرض نتيجة نجاح إلا بعد رد المزود.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                NovaTechPanel(
                  accentColor: _magenta,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _magenta, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'إعدادات عملية الصك',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 25),
                      const Text(
                        'ملف السرعة المستهدف',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _profiles.contains(_selectedProfile) ? _selectedProfile : _profiles.first,
                            dropdownColor: const Color(0xFF0A0E17),
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded, color: _magenta),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            items: _profiles.map((profile) => DropdownMenuItem(
                              value: profile,
                              child: Text(profile == 'default' ? 'الافتراضي' : profile),
                            )).toList(),
                            onChanged: _isForging ? null : (value) {
                              if (value != null) setState(() => _selectedProfile = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'عدد البطاقات',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${_voucherCount.toInt()} بطاقة',
                            style: const TextStyle(color: _magenta, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: _magenta,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.white,
                          overlayColor: _magenta.withOpacity(0.18),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _voucherCount,
                          min: 10,
                          max: 500,
                          divisions: 49,
                          onChanged: _isForging ? null : (value) => setState(() => _voucherCount = value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'طول الرمز الرقمي',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${_codeLength.toInt()} خانات',
                            style: const TextStyle(color: _cyan, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: _cyan,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.white,
                          overlayColor: _cyan.withOpacity(0.18),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _codeLength,
                          min: 4,
                          max: 16,
                          divisions: 12,
                          onChanged: _isForging ? null : (value) => setState(() => _codeLength = value),
                        ),
                      ),
                      const Text(
                        'حدود التوليد: من 1 إلى 500 بطاقة، وطول الرمز من 4 إلى 16 خانة.',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: (_isForging ? Colors.grey : _magenta).withOpacity(0.22),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isForging || provider.isLoading ? null : _startForgingProcess,
                      icon: Icon(_isForging ? Icons.sync_rounded : Icons.auto_awesome_rounded),
                      label: Text(
                        _isForging ? 'جارٍ صك البطاقات...' : 'بدء صك البطاقات',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _magenta,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'تنبيه: تأكد من وجود ملف السرعة المحدد على الراوتر قبل بدء العملية. قد تُنشأ بعض البطاقات قبل ظهور خطأ إذا انقطع الاتصال أثناء التنفيذ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
