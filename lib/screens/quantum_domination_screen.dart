import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/quantum_domination_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/cyber_data_stream.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class QuantumDominationScreen extends StatefulWidget {
  const QuantumDominationScreen({super.key});

  @override
  State<QuantumDominationScreen> createState() => _QuantumDominationScreenState();
}

class _QuantumDominationScreenState extends State<QuantumDominationScreen> {
  double _socialLimit = 50;
  double _streamingLimit = 50;
  double _gamingLimit = 50;
  bool _limitsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<QuantumDominationProvider>();
      await provider.start();
      if (!mounted || _limitsLoaded) return;
      setState(() {
        _gamingLimit = (provider.currentLimitMbps(TrafficCategory.gaming) ?? 50).clamp(1, 100).toDouble();
        _socialLimit = (provider.currentLimitMbps(TrafficCategory.social) ?? 50).clamp(1, 100).toDouble();
        _streamingLimit = (provider.currentLimitMbps(TrafficCategory.streaming) ?? 50).clamp(1, 100).toDouble();
        _limitsLoaded = true;
      });
    });
  }

  Future<void> _applyLimit(TrafficCategory category, int value) async {
    final provider = context.read<QuantumDominationProvider>();
    final success = await provider.setLimit(category, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'تم تطبيق الحد والتحقق من قراءة الطابور.' : provider.error),
      backgroundColor: success ? const Color(0xFF176B55) : const Color(0xFF9D2634),
    ));
  }

  Future<void> _toggleGamingPriority(bool enabled) async {
    final provider = context.read<QuantumDominationProvider>();
    final success = await provider.enableGamingPriority(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? (enabled ? 'تم ضبط أولوية الطابور الحالي إلى الدرجة الأولى.' : 'تم ضبط أولوية الطابور الحالي إلى الدرجة الثامنة.')
          : provider.error),
      backgroundColor: success ? const Color(0xFF176B55) : const Color(0xFF9D2634),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuantumDominationProvider>(
      builder: (context, state, child) {
        final connected = context.watch<ConnectionProvider>().isConnected;
        final gamingQueue = state.queueFor(TrafficCategory.gaming);
        final socialQueue = state.queueFor(TrafficCategory.social);
        final streamingQueue = state.queueFor(TrafficCategory.streaming);
        final gamingPriority = state.currentPriority(TrafficCategory.gaming);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('مصفوفة تدفق البيانات والتحكم'),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'تحديث من الراوتر',
                  onPressed: state.isLoading ? null : () => state.refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: ParticleMatrixBg(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    NovaTechPanel(
                      accentColor: const Color(0xFF00E5FF),
                      child: Column(
                        children: [
                          CyberDataStream(
                            gamingTraffic: state.gamingLoad,
                            socialTraffic: state.socialLoad,
                            streamingTraffic: state.streamingLoad,
                          ),
                          const Text(
                            'معدل التدفق محسوب من عدادات الطوابير الفعلية بين قراءتين.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              _rate('الألعاب', state.gamingRate, const Color(0xFF4CAE7D)),
                              _rate('التواصل', state.socialRate, const Color(0xFFE040FB)),
                              _rate('البث المرئي', state.streamingRate, const Color(0xFFFF6B6B)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!connected)
                      const _Notice('اتصل بالراوتر لقراءة الطوابير الحقيقية.', warning: true),
                    if (state.error.isNotEmpty)
                      _Notice(state.error, warning: true),
                    const SizedBox(height: 8),
                    NovaTechPanel(
                      accentColor: const Color(0xFFE040FB),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('حدود السرعة للطوابير الموجودة',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text(
                            'تُعدّل هذه الأدوات الطابور الموجود فقط إذا تطابق اسمه أو تعليقه مع الفئة. لا تُنشأ قواعد تصنيف جديدة تلقائياً.',
                            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                          ),
                          const Divider(color: Colors.white24, height: 26),
                          _limiter(
                            title: 'الألعاب',
                            value: _gamingLimit,
                            color: const Color(0xFF4CAE7D),
                            configured: gamingQueue != null,
                            disabled: state.isApplying || !connected,
                            onChanged: (v) => setState(() => _gamingLimit = v),
                            onApply: () => _applyLimit(TrafficCategory.gaming, _gamingLimit.round()),
                          ),
                          const SizedBox(height: 18),
                          _limiter(
                            title: 'منصات التواصل',
                            value: _socialLimit,
                            color: const Color(0xFFE040FB),
                            configured: socialQueue != null,
                            disabled: state.isApplying || !connected,
                            onChanged: (v) => setState(() => _socialLimit = v),
                            onApply: () => _applyLimit(TrafficCategory.social, _socialLimit.round()),
                          ),
                          const SizedBox(height: 18),
                          _limiter(
                            title: 'بث الفيديو',
                            value: _streamingLimit,
                            color: const Color(0xFFFF6B6B),
                            configured: streamingQueue != null,
                            disabled: state.isApplying || !connected,
                            onChanged: (v) => setState(() => _streamingLimit = v),
                            onApply: () => _applyLimit(TrafficCategory.streaming, _streamingLimit.round()),
                          ),
                          if (state.isApplying)
                            const Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: LinearProgressIndicator(color: Color(0xFF00E5FF)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    NovaTechPanel(
                      accentColor: const Color(0xFF4CAE7D),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('أولوية طابور الألعاب',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                            gamingQueue == null
                                ? 'لا يوجد طابور ألعاب معروف. لن يتم تعديل أي طابور آخر.'
                                : 'الطابور المطابق: ${gamingQueue['name'] ?? 'بدون اسم'} — الأولوية الحالية: ${gamingPriority ?? 'غير محددة'}.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: state.isApplying || !connected || gamingQueue == null
                                      ? null
                                      : () => _toggleGamingPriority(true),
                                  icon: const Icon(Icons.sports_esports_rounded),
                                  label: const Text('أولوية قصوى'),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF176B55)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: state.isApplying || !connected || gamingQueue == null
                                      ? null
                                      : () => _toggleGamingPriority(false),
                                  child: const Text('أولوية عادية'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'الأولوية تخص الطابور الموجود فقط. لا يعني ذلك تصنيف حزم الألعاب تلقائياً حسب بروتوكولها.',
                            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'عناصر شجرة الطوابير المقروءة: ${state.queues.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rate(String title, int mbps, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$title: $mbps ميغابت/ث', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _limiter({
    required String title,
    required double value,
    required Color color,
    required bool configured,
    required bool disabled,
    required ValueChanged<double> onChanged,
    required VoidCallback onApply,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text('${value.round()} ميغابت/ث', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(1, 100).toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: disabled || !configured ? null : onChanged,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                configured ? 'مرتبط بطابور موجود' : 'لا يوجد طابور مطابق',
                style: TextStyle(color: configured ? Colors.white54 : Colors.orangeAccent, fontSize: 11),
              ),
            ),
            FilledButton(
              onPressed: disabled || !configured ? null : onApply,
              style: FilledButton.styleFrom(backgroundColor: color.withOpacity(.85)),
              child: const Text('تطبيق الحد'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.warning = false});
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (warning ? Colors.orangeAccent : const Color(0xFF00E5FF)).withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (warning ? Colors.orangeAccent : const Color(0xFF00E5FF)).withOpacity(.45)),
        ),
        child: Text(message, style: const TextStyle(color: Colors.white70, height: 1.5)),
      );
}
