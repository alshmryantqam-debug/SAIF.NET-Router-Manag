import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/cyber_pcc_reactor.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

/// شاشة دمج الخطوط.
/// يمكن تمرير بيانات الخطوط من مزود الاتصال عند ربطه؛
/// البيانات الافتراضية أدناه للعرض فقط ولا تمثل حالة الراوتر الفعلية.
class PccFusionScreen extends StatefulWidget {
  final List<WanLine>? wans;

  const PccFusionScreen({Key? key, this.wans}) : super(key: key);

  @override
  State<PccFusionScreen> createState() => _PccFusionScreenState();
}

class _PccFusionScreenState extends State<PccFusionScreen> {
  static const _cyan = Color(0xFF00E5FF);
  static const _magenta = Color(0xFFE040FB);
  static const _green = Color(0xFF4CAE7D);
  static const _red = Color(0xFFFF5252);
  static const _gold = Color(0xFFE5C158);

  late final List<WanLine> _demoWans = [
    WanLine(
      name: 'الخط الأول',
      isOnline: true,
      color: _cyan,
      angle: math.pi * 1.25,
    ),
    WanLine(
      name: 'الخط الثاني',
      isOnline: true,
      color: _magenta,
      angle: math.pi * 1.75,
    ),
    WanLine(
      name: 'الخط الثالث',
      isOnline: false,
      color: _red,
      angle: math.pi * 0.25,
    ),
    WanLine(
      name: 'الخط الاحتياطي',
      isOnline: true,
      color: _green,
      angle: math.pi * 0.75,
    ),
  ];

  List<WanLine> get _wans => widget.wans ?? _demoWans;

  void _showNotConnected(String operation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('لم يُربط إجراء "$operation" بمزود الراوتر بعد.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF182337),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _wans.where((wan) => wan.isOnline).length;

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
            'مفاعل دمج الخطوط',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
              shadows: [Shadow(color: _cyan, blurRadius: 10)],
            ),
          ),
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              physics: const BouncingScrollPhysics(),
              children: [
                NovaTechPanel(
                  accentColor: _cyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: CyberPccReactor(wans: _wans),
                ),
                const SizedBox(height: 14),
                NovaTechPanel(
                  accentColor: onlineCount > 0 ? _cyan : _red,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        onlineCount > 0
                            ? Icons.hub_rounded
                            : Icons.warning_amber_rounded,
                        color: onlineCount > 0 ? _cyan : _red,
                        size: 25,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              onlineCount > 0
                                  ? 'منظومة الدمج قيد العرض'
                                  : 'لا توجد خطوط متصلة في بيانات العرض',
                              style: TextStyle(
                                color: onlineCount > 0 ? _cyan : _red,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الخطوط المتاحة: $onlineCount من ${_wans.length} — بيانات توضيحية',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.shield_outlined,
                          color: Colors.white38, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                NovaTechPanel(
                  accentColor: _cyan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_tree_rounded,
                              color: _cyan, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'منافذ التزويد بالإنترنت',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 22),
                      for (final wan in _wans) _buildWanCard(wan),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TacticalButton(
                        text: 'تفريغ الجلسات',
                        icon: Icons.cleaning_services_rounded,
                        color: _gold,
                        onPressed: () => _showNotConnected('تفريغ الجلسات'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TacticalButton(
                        text: 'موازنة الأحمال',
                        icon: Icons.balance_rounded,
                        color: _cyan,
                        onPressed: () => _showNotConnected('موازنة الأحمال'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'وضع العرض فقط: لن تُعدّل قواعد التوجيه أو الجلسات حتى ربط الأوامر والتحقق منها.',
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

  Widget _buildWanCard(WanLine wan) {
    final statusColor = wan.isOnline ? wan.color : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.38)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              wan.isOnline ? Icons.router_rounded : Icons.portable_wifi_off,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  wan.isOnline
                      ? 'متصل — ضمن مسارات الدمج'
                      : 'غير متصل — يلزم التحقق من الخط',
                  style: TextStyle(
                    color: wan.isOnline ? Colors.white60 : _red,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                wan.isOnline ? 'بانتظار القياس' : 'لا توجد حركة',
                style: TextStyle(
                  color: wan.isOnline ? statusColor : _red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'السرعة الحية غير مربوطة',
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TacticalButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TacticalButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
