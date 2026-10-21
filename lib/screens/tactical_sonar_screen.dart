import 'dart:io' show InternetAddress;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mikrotik_provider.dart';
import '../widgets/cyber_target_crosshair.dart';
import '../widgets/cyber_text_field.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const Color _sonarCyan = Color(0xFF00E5FF);
const Color _sonarPink = Color(0xFFE040FB);
const Color _sonarRed = Color(0xFFFF5252);

class TacticalSonarScreen extends ConsumerStatefulWidget {
  const TacticalSonarScreen({super.key});

  @override
  ConsumerState<TacticalSonarScreen> createState() => _TacticalSonarScreenState();
}

class _TacticalSonarScreenState extends ConsumerState<TacticalSonarScreen> {
  final TextEditingController _ipController = TextEditingController(text: '8.8.8.8');
  bool _isPinging = false;
  bool _isTimeout = false;
  String? _validationMessage;
  String _latency = '—';
  String _packetDrop = '—';
  String _minLatency = '—';
  String _maxLatency = '—';
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_onTargetChanged);
  }

  void _onTargetChanged() {
    if (mounted) setState(() {});
  }

  bool _isValidTarget(String value) {
    final target = value.trim();
    if (target.isEmpty) return false;
    if (InternetAddress.tryParse(target) != null) return true;
    if (target.length > 253 || target.contains('://') ||
        target.contains('/') || target.contains(' ')) return false;
    return target.split('.').every((label) =>
        label.isNotEmpty && label.length <= 63 &&
        !label.startsWith('-') && !label.endsWith('-') &&
        RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(label));
  }

  String? _readMetric(Map<String, dynamic> result, List<String> keys) {
    for (final key in keys) {
      final value = result[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();
        if (text.toLowerCase() != 'null') return text;
      }
    }
    return null;
  }

  bool _isTimeoutResult(Map<String, dynamic>? result) {
    if (result == null || result.isEmpty) return true;
    final status = result['status']?.toString().trim().toLowerCase();
    if (status != null && status.isNotEmpty &&
        status != 'ok' && status != 'success') return true;
    final time = _readMetric(result, <String>['time', 'avg-rtt', 'rtt']);
    if (time == null) return true;
    return time.toLowerCase().contains('timeout') ||
        time.toLowerCase() == 'unreachable';
  }

  Future<void> _executePingLock() async {
    if (_isPinging) {
      // لا يمكن إلغاء طلب الراوتر الجاري؛ نتجاهل نتيجته عند عودتها.
      ++_requestGeneration;
      setState(() {
        _isPinging = false;
        _isTimeout = false;
      });
      return;
    }

    final target = _ipController.text.trim();
    if (!_isValidTarget(target)) {
      setState(() {
        _validationMessage = 'أدخل عنواناً صحيحاً أو اسم مضيف صالحاً.';
        _isTimeout = false;
      });
      return;
    }

    final apiService = ref.read(mikrotikApiProvider.notifier).api;
    if (apiService == null) {
      setState(() {
        _isPinging = false;
        _isTimeout = true;
        _validationMessage = 'سجّل الدخول إلى الراوتر أولاً لتشغيل الفحص الحقيقي.';
      });
      _showMessage('محرك الاتصال غير متصل. سجّل الدخول إلى الراوتر أولاً.');
      return;
    }

    final generation = ++_requestGeneration;
    setState(() {
      _validationMessage = null;
      _isPinging = true;
      _isTimeout = false;
      _latency = 'جارٍ…';
      _packetDrop = 'جارٍ…';
      _minLatency = '—';
      _maxLatency = '—';
    });

    try {
      final result = await apiService.pingTarget(target);
      if (!mounted || generation != _requestGeneration) return;

      if (_isTimeoutResult(result)) {
        setState(() {
          _isPinging = false;
          _isTimeout = true;
          _latency = 'انتهت المهلة';
          _packetDrop = '100%';
          _minLatency = '—';
          _maxLatency = '—';
        });
        return;
      }

      final latency = _readMetric(result!, <String>['avg-rtt', 'time', 'rtt']) ?? '—';
      final packetLoss = _readMetric(result, <String>['packet-loss']) ?? '—';
      final minLatency = _readMetric(result, <String>['min-rtt', 'min-rtt-time']) ?? latency;
      final maxLatency = _readMetric(result, <String>['max-rtt', 'max-rtt-time']) ?? latency;
      setState(() {
        _isPinging = false;
        _isTimeout = false;
        _latency = latency;
        _packetDrop = packetLoss;
        _minLatency = minLatency;
        _maxLatency = maxLatency;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isPinging = false;
        _isTimeout = true;
        _latency = 'فشل';
        _packetDrop = '100%';
      });
      _showMessage('تعذّر تنفيذ الفحص: ' + error.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: _sonarRed,
      ));
  }

  @override
  void dispose() {
    ++_requestGeneration;
    _ipController.removeListener(_onTargetChanged);
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(mikrotikApiProvider);
    final statusColor = _isTimeout ? _sonarRed : (_isPinging ? _sonarPink : _sonarCyan);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF070914),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('السونار التكتيكي', style: TextStyle(
            fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white,
            shadows: <Shadow>[Shadow(color: _sonarCyan, blurRadius: 10)],
          )),
          centerTitle: true,
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.radar_rounded, color: statusColor, size: 15),
                            const SizedBox(width: 8),
                            Flexible(child: Text(
                              _isTimeout ? 'تعذّر الوصول إلى الهدف'
                                  : _isPinging ? 'جارٍ إرسال نبضة حقيقية عبر الراوتر'
                                  : connectionState.isConnected ? 'السونار جاهز — الراوتر متصل'
                                  : 'السونار في وضع الاستعداد — الراوتر غير متصل',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      CyberTargetCrosshair(isPinging: _isPinging, isTimeout: _isTimeout),
                      Text(
                        _ipController.text.trim().isEmpty ? 'لا يوجد هدف محدد'
                            : 'الهدف المحدد  •  ' + _ipController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 18),
                      NovaTechPanel(
                        accentColor: _sonarCyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('تحديد الهدف', style: TextStyle(
                              color: _sonarCyan, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            CyberTextField(
                              controller: _ipController,
                              label: 'عنوان الهدف أو اسم المضيف',
                              hint: 'مثال: 192.168.88.1',
                              helper: 'يُقبل عنوان الإصدار الرابع أو السادس واسم المضيف',
                              icon: Icons.track_changes_rounded,
                              accentColor: _sonarCyan,
                              keyboardType: TextInputType.url,
                              enabled: !_isPinging,
                            ),
                            if (_validationMessage != null) ...<Widget>[
                              const SizedBox(height: 8),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(_validationMessage!, style: const TextStyle(
                                  color: _sonarRed, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      NovaTechPanel(
                        accentColor: _sonarPink,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('قياسات الاتصال', style: TextStyle(
                              color: _sonarPink, fontSize: 13, fontWeight: FontWeight.w900)),
                            const Divider(color: Colors.white24, height: 24),
                            Row(children: <Widget>[
                              Expanded(child: _telemetryBlock('زمن الاستجابة', _latency, _sonarCyan)),
                              const SizedBox(width: 10),
                              Expanded(child: _telemetryBlock('فقد الحزم', _packetDrop, _sonarRed)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: <Widget>[
                              Expanded(child: _telemetryBlock('أدنى زمن', _minLatency, Colors.white70)),
                              const SizedBox(width: 10),
                              Expanded(child: _telemetryBlock('أعلى زمن', _maxLatency, Colors.white70)),
                            ]),
                            const SizedBox(height: 12),
                            Text(
                              connectionState.isConnected
                                  ? 'القياسات ناتجة عن طلب الفحص الذي ينفذه الراوتر.'
                                  : 'تُعرض القياسات بعد تسجيل الدخول والاتصال بالراوتر.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: NovaCyberButton(
                          text: _isPinging ? 'إيقاف الفحص' : 'بدء فحص الهدف',
                          icon: _isPinging ? Icons.stop_circle_rounded : Icons.my_location_rounded,
                          color: _isPinging ? _sonarRed : _sonarCyan,
                          onPressed: _executePingLock,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _telemetryBlock(String title, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(value, textAlign: TextAlign.center, style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()])),
          const SizedBox(height: 5),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(
            color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
