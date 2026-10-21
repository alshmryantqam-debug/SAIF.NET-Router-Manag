import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../widgets/cyber_hexagon_core.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _violet = Color(0xFFE040FB);
const _green = Color(0xFF52E0A1);
const _red = Color(0xFFFF657A);
const _text = Color(0xFFF3F6FF);
const _muted = Color(0xFFB6C2D5);

class NovaCoreEngineScreen extends ConsumerStatefulWidget {
  const NovaCoreEngineScreen({super.key});

  @override
  ConsumerState<NovaCoreEngineScreen> createState() =>
      _NovaCoreEngineScreenState();
}

class _NovaCoreEngineScreenState extends ConsumerState<NovaCoreEngineScreen> {
  bool _gamingMode = false;
  bool _antiNetcut = false;
  bool _isChecking = false;
  String? _status;
  bool _statusIsError = false;

  bool get _engineSelected => _gamingMode || _antiNetcut;

  Future<void> _inspectRouter() async {
    final connection = ref.read(connectionProvider);
    if (!connection.isConnected) {
      setState(() {
        _status = 'لا يوجد اتصال فعّال بالراوتر. اتصل بالراوتر أولاً.';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _status = 'جارٍ فحص قوائم الجدار الناري والسرعات على الراوتر...';
      _statusIsError = false;
    });

    try {
      final service = ref.read(mikrotikProvider);
      final results = await Future.wait([
        service.firewallRules(),
        service.simpleQueues(),
      ]);
      if (!mounted) return;

      final firewallCount = results[0].length;
      final queueCount = results[1].length;
      setState(() {
        _isChecking = false;
        _status =
            'اكتمل الفحص: $firewallCount قاعدة جدار ناري و$queueCount قائمة سرعة. لم تُغيّر أي إعدادات.';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _status = 'تعذّر إكمال الفحص: ${error.toString().replaceFirst('Exception: ', '')}';
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectedProvider);
    final engineColor = _engineSelected ? _cyan : _red;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xCC070B14),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _cyan),
        title: const Text(
          'نواة نـوڨـا المركزية',
          style: TextStyle(
            color: _text,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            shadows: [Shadow(color: _cyan, blurRadius: 12)],
          ),
        ),
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              CyberHexagonCore(isActive: _engineSelected),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  _engineSelected
                      ? 'تم اختيار ميزات المحرك — لم تُفعّل على الراوتر بعد'
                      : 'المحرك غير محدد التشغيل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: engineColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: [
                    _featurePanel(
                      title: 'معزّز الألعاب وجودة الخدمة (QoS)',
                      description:
                          'تهيئة أولوية حركة الألعاب لتقليل التنافس على سعة الاتصال. النتيجة تعتمد على سرعة الخط وقواعد الشبكة الحالية.',
                      detail: 'أولوية الألعاب • إدارة ازدحام الشبكة',
                      icon: Icons.sports_esports_rounded,
                      color: _violet,
                      value: _gamingMode,
                      onChanged: (value) => setState(() {
                        _gamingMode = value;
                        _status = null;
                      }),
                    ),
                    _featurePanel(
                      title: 'درع استقرار الشبكة',
                      description:
                          'فحص قواعد الجدار الناري وقوائم السرعة الحالية. لا يمكن ضمان منع كل تطبيقات قطع الاتصال، ولا يُعد جدول ARP مشفّراً.',
                      detail: 'فحص الإعدادات • دون تعديل تلقائي',
                      icon: Icons.shield_moon_rounded,
                      color: _green,
                      value: _antiNetcut,
                      onChanged: (value) => setState(() {
                        _antiNetcut = value;
                        _status = null;
                      }),
                    ),
                    NovaTechPanel(
                      accentColor: connected ? _green : _red,
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            connected
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            color: connected ? _green : _red,
                            size: 25,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connected
                                      ? 'الاتصال بالراوتر قائم'
                                      : 'الراوتر غير متصل',
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  connected
                                      ? 'يمكن فحص الإعدادات الحالية. التطبيق لا يكتب قواعد QoS أو الحماية من هذه الشاشة حتى تتوفر آلية تطبيق آمنة مع نسخة احتياطية وتراجع.'
                                      : 'اتصل بالراوتر أولاً لفحص إعداداته الفعلية.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      NovaTechPanel(
                        accentColor: _statusIsError ? _red : _cyan,
                        margin: EdgeInsets.zero,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _statusIsError
                                  ? Icons.error_outline_rounded
                                  : Icons.fact_check_rounded,
                              color: _statusIsError ? _red : _cyan,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _status!,
                                style: TextStyle(
                                  color: _statusIsError ? _red : _text,
                                  fontSize: 13,
                                  height: 1.7,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: NovaCyberButton(
                  text: _isChecking
                      ? 'جارٍ فحص إعدادات الراوتر...'
                      : 'فحص الإعدادات الفعلية',
                  icon: _isChecking
                      ? Icons.sync_rounded
                      : Icons.radar_rounded,
                  color: _cyan,
                  onPressed: _isChecking ? null : _inspectRouter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featurePanel({
    required String title,
    required String description,
    required String detail,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return NovaTechPanel(
      accentColor: value ? color : const Color(0xFF64748B),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(value ? 0.15 : 0.06),
              border: Border.all(color: color.withOpacity(value ? 0.75 : 0.3)),
            ),
            child: Icon(icon, color: value ? color : _muted, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  detail,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch.adaptive(
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
