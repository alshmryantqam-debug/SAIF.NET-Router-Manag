import 'dart:ui';

import 'package:flutter/material.dart';

import '../widgets/biometric_hold_button.dart';
import '../widgets/cyber_3d_sphere.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

/// Extreme sci-fi control surface. Sensitive actions are deliberately disabled
/// until a verified, authenticated RouterOS API service is connected.
class GodModeScreen extends StatelessWidget {
  const GodModeScreen({super.key});

  static const Color _red = Color(0xFFFF5252);
  static const Color _amber = Color(0xFFE5C158);
  static const Color _cyan = Color(0xFF00E5FF);

  void _showPendingNotice(BuildContext context, String commandName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'لم يُنفّذ $commandName. يلزم ربط API موثّق والتحقق من صلاحيات الراوتر أولاً.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF5A1720),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'وضع التحكم المطلق',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Colors.white,
            shadows: [Shadow(color: _red, blurRadius: 12)],
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: _red),
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Cyber3DSphere(color: _red),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.10),
                  border: Border.all(color: _red.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: _red.withOpacity(0.08), blurRadius: 16),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _red, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'وضع العرض — أوامر النواة غير موصولة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _red,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _CoreStatusStrip(),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const Text(
                      'بروتوكولات الطوارئ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'EMERGENCY PROTOCOLS  /  API AUTHORIZATION REQUIRED',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 14),
                    NovaTechPanel(
                      accentColor: _amber,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CommandHeading(
                            icon: Icons.cleaning_services_rounded,
                            title: 'تفريغ ذاكرة DNS المؤقتة',
                            subtitle: 'DNS CACHE FLUSH',
                            color: _amber,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الإجراء غير متاح حتى توصيل خدمة RouterOS والتحقق من الراوتر المستهدف. الضغط المطوّل هنا لا ينفّذ أي أمر شبكي.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          BiometricHoldButton(
                            text: 'اضغط مطولاً لطلب التفريغ',
                            color: _amber,
                            onExecute: () =>
                                _showPendingNotice(context, 'تفريغ DNS'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    NovaTechPanel(
                      accentColor: _red,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CommandHeading(
                            icon: Icons.power_settings_new_rounded,
                            title: 'إعادة تشغيل الراوتر',
                            subtitle: 'SYSTEM REBOOT',
                            color: _red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'قد يؤدي إعادة التشغيل إلى انقطاع اتصال جميع المشتركين. لن يُرسل الأمر قبل ربط API آمن وإظهار الراوتر المستهدف وتأكيد إضافي.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          BiometricHoldButton(
                            text: 'اضغط مطولاً لطلب إعادة التشغيل',
                            color: _red,
                            onExecute: () =>
                                _showPendingNotice(context, 'إعادة التشغيل'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ApiNotice(),
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

class _CoreStatusStrip extends StatelessWidget {
  const _CoreStatusStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _StatusCell(label: 'API LINK', value: 'OFFLINE')),
        SizedBox(width: 8),
        Expanded(child: _StatusCell(label: 'AUTH', value: 'PENDING')),
        SizedBox(width: 8),
        Expanded(child: _StatusCell(label: 'COMMANDS', value: 'LOCKED')),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.22)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFF7777),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandHeading extends StatelessWidget {
  const _CommandHeading({
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
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.lock_outline_rounded, color: color.withOpacity(0.7)),
      ],
    );
  }
}

class _ApiNotice extends StatelessWidget {
  const _ApiNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: Color(0xFF00E5FF), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ملاحظة أمنية: الضغط المطوّل ليس تحققًا بيومتريًا حقيقيًا. العمليات الحساسة معلّقة إلى حين ربط API موثّق، وفحص الصلاحيات، والتحقق من الهدف قبل إرسال أي أمر.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
