import 'dart:io' show InternetAddress;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../widgets/cyber_target_crosshair.dart';
import '../widgets/cyber_text_field.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const Color _sonarCyan = Color(0xFF00E5FF);
const Color _sonarPink = Color(0xFFE040FB);
const Color _sonarRed = Color(0xFFFF5252);

class TacticalSonarScreen extends StatefulWidget {
  const TacticalSonarScreen({super.key});

  @override
  State<TacticalSonarScreen> createState() => _TacticalSonarScreenState();
}

class _TacticalSonarScreenState extends State<TacticalSonarScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: '8.8.8.8');
  bool _isPinging = false;
  bool _isTimeout = false;
  String? _validationMessage;

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
    final address = InternetAddress.tryParse(target);
    if (address != null) return true;

    // Allow a conventional DNS hostname without accepting URLs or paths.
    if (target.length > 253 || target.contains('://') || target.contains('/')) {
      return false;
    }
    final labels = target.split('.');
    return labels.every((label) =>
        label.isNotEmpty &&
        label.length <= 63 &&
        !label.startsWith('-') &&
        !label.endsWith('-') &&
        RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(label));
  }

  void _toggleSonar() {
    final target = _ipController.text.trim();
    if (!_isPinging && !_isValidTarget(target)) {
      setState(() {
        _validationMessage = 'أدخل عنوان IP أو اسم مضيف صالحاً.';
        _isTimeout = false;
      });
      return;
    }

    setState(() {
      _validationMessage = null;
      _isPinging = !_isPinging;
      _isTimeout = false;
    });

    // Visual prototype only. Real ICMP probing must be implemented in a
    // Riverpod service before displaying latency, loss, or timeout results.
  }

  @override
  void dispose() {
    _ipController.removeListener(_onTargetChanged);
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isTimeout
        ? _sonarRed
        : _isPinging
            ? _sonarPink
            : _sonarCyan;

    return Scaffold(
      backgroundColor: const Color(0xFF070914),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'السونار التكتيكي',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Colors.white,
            shadows: <Shadow>[Shadow(color: _sonarCyan, blurRadius: 10)],
          ),
        ),
        centerTitle: true,
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 34,
                ),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.radar_rounded,
                              color: statusColor, size: 15),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isTimeout
                                  ? 'تعذّر الوصول إلى الهدف'
                                  : _isPinging
                                      ? 'عرض بصري قيد التشغيل — لا يوجد فحص فعلي'
                                      : 'نظام التصويب في وضع الاستعداد',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CyberTargetCrosshair(
                      isPinging: _isPinging,
                      isTimeout: _isTimeout,
                    ),
                    Text(
                      _ipController.text.trim().isEmpty
                          ? 'لا يوجد هدف محدد'
                          : 'الهدف المحدد  •  ${_ipController.text.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    NovaTechPanel(
                      accentColor: _sonarCyan,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'تحديد الهدف',
                            style: TextStyle(
                              color: _sonarCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CyberTextField(
                            controller: _ipController,
                            label: 'عنوان IP أو اسم المضيف',
                            hint: 'مثال: 192.168.88.1 أو example.com',
                            helper: 'يُقبل IPv4 وIPv6 واسم مضيف DNS',
                            icon: Icons.track_changes_rounded,
                            accentColor: _sonarCyan,
                            keyboardType: TextInputType.url,
                            enabled: !_isPinging,
                          ),
                          if (_validationMessage != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _validationMessage!,
                                style: const TextStyle(
                                  color: _sonarRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                          const Text(
                            'قياسات الاتصال',
                            style: TextStyle(
                              color: _sonarPink,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _telemetryBlock(
                                  'زمن الاستجابة',
                                  '— ms',
                                  _sonarCyan,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _telemetryBlock(
                                  'فقد الحزم',
                                  '— %',
                                  _sonarRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _telemetryBlock(
                                  'أدنى زمن',
                                  '— ms',
                                  Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _telemetryBlock(
                                  'أعلى زمن',
                                  '— ms',
                                  Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'القياسات غير متاحة حتى ربط خدمة Ping حقيقية عبر Riverpod.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: NovaCyberButton(
                        text: _isPinging
                            ? 'إيقاف العرض البصري'
                            : 'تفعيل عدسة التصويب',
                        icon: _isPinging
                            ? Icons.stop_circle_rounded
                            : Icons.my_location_rounded,
                        color: _isPinging ? _sonarRed : _sonarCyan,
                        onPressed: _toggleSonar,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'وضع التصميم: محاكاة بصرية فقط • لا تُرسل حزم ICMP حالياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
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
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
