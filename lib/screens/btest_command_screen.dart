import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/btest_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/cyber_btest_reactor.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class BtestCommandScreen extends StatefulWidget {
  const BtestCommandScreen({super.key});

  @override
  State<BtestCommandScreen> createState() => _BtestCommandScreenState();
}

class _BtestCommandScreenState extends State<BtestCommandScreen> {
  final _ipController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _packetSizeController = TextEditingController(text: '1400');
  String _protocol = 'udp';

  @override
  void dispose() {
    _ipController.dispose();
    _userController.dispose();
    _passController.dispose();
    _packetSizeController.dispose();
    super.dispose();
  }

  Future<void> _run(BtestProvider provider) async {
    final target = _ipController.text.trim();
    final packetSize = int.tryParse(_packetSizeController.text.trim()) ?? 0;
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنوان الراوتر الهدف أولاً.')),
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد اختبار السعة'),
          content: const Text(
            'سيُرسل الاختبار حركة بيانات فعلية لمدة لا تتجاوز 10 ثوانٍ وقد يرفع استهلاك الخط ومعالج الراوتر. تأكد من امتلاكك صلاحية اختبار الراوتر الهدف. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('بدء الاختبار'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;

    await provider.startTest(
      targetIp: target,
      protocol: _protocol,
      user: _userController.text.trim(),
      pass: _passController.text,
      packetSize: packetSize,
      durationSeconds: 10,
    );
    if (!mounted) return;
    _passController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'مفاعل قياس سعة الاتصال',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          centerTitle: true,
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: Consumer<BtestProvider>(
              builder: (context, state, child) {
                final connected = context.watch<ConnectionProvider>().isConnected;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    NovaTechPanel(
                      accentColor: const Color(0xFF00D9FF),
                      child: Column(
                        children: [
                          CyberBtestReactor(
                            rxSpeed: state.rxSpeed,
                            txSpeed: state.txSpeed,
                            isTesting: state.isTesting,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: _SpeedReadout(
                                  label: 'سرعة الاستقبال',
                                  value: state.rxSpeed,
                                  color: const Color(0xFF00D9FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SpeedReadout(
                                  label: 'سرعة الإرسال',
                                  value: state.txSpeed,
                                  color: const Color(0xFFE040FB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          if (state.duration.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                'مدة الاختبار: ${state.duration} • الحزم المفقودة: ${state.lostPackets}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'يعيد الراوتر النتائج بعد انتهاء الأمر؛ لا يتيح REST عرضاً متدفقاً لحظياً أثناء التنفيذ.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    if (!connected)
                      const _StatusNote(
                        text: 'اتصل أولاً براوتر الإدارة من شاشة الاتصال.',
                        warning: true,
                      ),
                    if (state.errorMessage.isNotEmpty)
                      _StatusNote(text: state.errorMessage, warning: true),
                    const SizedBox(height: 14),
                    NovaTechPanel(
                      accentColor: const Color(0xFFE040FB),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إعدادات الراوتر الهدف',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يجب أن يكون خادم اختبار السعة مفعّلاً على الراوتر الهدف، وأن يسمح الجدار الناري بالاتصال المطلوب.',
                            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _ipController,
                            label: 'عنوان الراوتر الهدف',
                            hint: 'مثال: 192.168.88.2',
                            icon: Icons.router_rounded,
                            enabled: !state.isTesting,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _userController,
                            label: 'اسم مستخدم الراوتر الهدف',
                            hint: 'اتركه فارغاً إذا لم يكن مطلوباً',
                            icon: Icons.person_outline_rounded,
                            enabled: !state.isTesting,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _passController,
                            label: 'كلمة مرور الراوتر الهدف',
                            hint: 'لا تُحفظ داخل التطبيق',
                            icon: Icons.lock_outline_rounded,
                            enabled: !state.isTesting,
                            obscure: true,
                          ),
                          const SizedBox(height: 16),
                          const Text('بروتوكول الاختبار', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _ProtocolChoice(
                                label: 'UDP',
                                selected: _protocol == 'udp',
                                color: const Color(0xFF00D9FF),
                                enabled: !state.isTesting,
                                onTap: () => setState(() => _protocol = 'udp'),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _ProtocolChoice(
                                label: 'TCP',
                                selected: _protocol == 'tcp',
                                color: const Color(0xFFE040FB),
                                enabled: !state.isTesting,
                                onTap: () => setState(() => _protocol = 'tcp'),
                              )),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _packetSizeController,
                            label: 'حجم الحزمة بالبايت',
                            hint: _protocol == 'udp' ? 'من 28 إلى 64000؛ يستخدمه UDP' : 'يُطبّق على UDP فقط',
                            icon: Icons.data_array_rounded,
                            enabled: !state.isTesting && _protocol == 'udp',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'مدة الاختبار ثابتة عند 10 ثوانٍ لتقليل خطر إغراق الخط. اختبارات السعة قد تؤثر مؤقتاً في المشتركين.',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: !connected
                            ? null
                            : state.isTesting
                                ? state.stopTest
                                : () => _run(state),
                        icon: Icon(state.isTesting ? Icons.stop_circle_outlined : Icons.speed_rounded),
                        label: Text(
                          state.isTesting ? 'إلغاء طلب الاختبار' : 'بدء اختبار السعة الحقيقي',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: state.isTesting
                              ? const Color(0xFFB52F46)
                              : const Color(0xFF087D9A),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00D9FF)),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        filled: true,
        fillColor: Colors.black.withOpacity(.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const Text('ميغابت/ث', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      );
}

class _ProtocolChoice extends StatelessWidget {
  const _ProtocolChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.17) : Colors.black.withOpacity(.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: selected ? color : Colors.white70, fontWeight: FontWeight.w900)),
          ),
        ),
      );
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.text, this.warning = false});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (warning ? Colors.orangeAccent : const Color(0xFF00D9FF)).withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (warning ? Colors.orangeAccent : const Color(0xFF00D9FF)).withOpacity(.5)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.5)),
      );
}
