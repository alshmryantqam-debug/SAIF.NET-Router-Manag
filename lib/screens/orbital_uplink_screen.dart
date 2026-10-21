import 'package:flutter/material.dart';

import '../widgets/cyber_satellite_radar.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

/// Orbital-themed control UI. Router telemetry and script execution are
/// intentionally marked unavailable until a real, authenticated service is wired.
class OrbitalUplinkScreen extends StatelessWidget {
  const OrbitalUplinkScreen({super.key});

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFE040FB);
  static const Color _green = Color(0xFF4CAE7D);

  void _showIntegrationNotice(BuildContext context, String protocol) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'لم يُنفّذ $protocol: خدمة RouterOS غير موصولة. هذه الشاشة واجهة فقط.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF352746),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'مركز القيادة المداري',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: _cyan, blurRadius: 10)],
          ),
        ),
        centerTitle: true,
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              const CyberSatelliteRadar(isConnected: false),
              const SizedBox(height: 4),
              const _ConnectionStatus(),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        label: 'LATENCY',
                        value: '--',
                        unit: 'ms',
                        icon: Icons.radar_rounded,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _TelemetryCard(
                        label: 'PACKET DROP',
                        value: '--',
                        unit: '%',
                        icon: Icons.network_check_rounded,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _TelemetryCard(
                        label: 'SAT LOCK',
                        value: '--',
                        unit: 'N/A',
                        icon: Icons.satellite_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const Text(
                      'أدوات إدارة الباكهول',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NovaTechPanel(
                      accentColor: _magenta,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ProtocolHeading(
                            icon: Icons.shield_moon_rounded,
                            title: 'TTL & MAC',
                            subtitle: 'تعديلات واجهة متقدمة',
                            color: _magenta,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'يتطلب هذا الإجراء تكامل RouterOS موثّقًا ومراجعة القواعد قبل تطبيق أي تغيير. لم يتم إرسال أي أوامر إلى الراوتر.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 16),
                          NovaCyberButton(
                            text: 'فحص تكامل TTL / MAC',
                            icon: Icons.integration_instructions_rounded,
                            color: _magenta,
                            onPressed: () =>
                                _showIntegrationNotice(context, 'TTL / MAC'),
                          ),
                        ],
                      ),
                    ),
                    NovaTechPanel(
                      accentColor: _green,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ProtocolHeading(
                            icon: Icons.route_rounded,
                            title: 'مسار الباكهول',
                            subtitle: 'توجيه واتصال',
                            color: _green,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'تغيير المسارات قد يقطع اتصال المشتركين أو يتجاوز قواعد الحماية. يلزم ربط الخدمة وفحص الحالة الحالية أولًا.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 16),
                          NovaCyberButton(
                            text: 'التحقق من تكامل التوجيه',
                            icon: Icons.alt_route_rounded,
                            color: _green,
                            onPressed: () =>
                                _showIntegrationNotice(context, 'التوجيه'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'DEMO MODE • لا توجد قياسات حية أو أوامر RouterOS مفعّلة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withOpacity(0.08),
        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_rounded, color: Color(0xFFFF5252), size: 15),
          SizedBox(width: 7),
          Text(
            'UPLINK: NOT CONNECTED',
            style: TextStyle(
              color: Color(0xFFFF7B7B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 21),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            unit,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolHeading extends StatelessWidget {
  const _ProtocolHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: color, fontSize: 10),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 18),
      ],
    );
  }
}
