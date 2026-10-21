import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hotspot_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/cyber_text_field.dart';
import '../widgets/particle_matrix_bg.dart';

class AddHotspotUserScreen extends ConsumerStatefulWidget {
  const AddHotspotUserScreen({super.key});

  @override
  ConsumerState<AddHotspotUserScreen> createState() =>
      _AddHotspotUserScreenState();
}

class _AddHotspotUserScreenState
    extends ConsumerState<AddHotspotUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _profileCtrl = TextEditingController(text: 'default');
  final _commentCtrl = TextEditingController();
  final _uptimeCtrl = TextEditingController();
  final _bytesCtrl = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static final Random _rnd = Random.secure();
  static const String _alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

  String _randomString(int len) =>
      List.generate(len, (_) => _alphabet[_rnd.nextInt(_alphabet.length)])
          .join();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _profileCtrl.dispose();
    _commentCtrl.dispose();
    _uptimeCtrl.dispose();
    _bytesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final bytes = int.tryParse(_bytesCtrl.text.trim()) ?? 0;

    final user = HotspotUser(
      name: _nameCtrl.text.trim(),
      password: _passCtrl.text,
      profile: _profileCtrl.text.trim().isEmpty
          ? 'default'
          : _profileCtrl.text.trim(),
      comment: _commentCtrl.text.trim(),
      limitUptime: _uptimeCtrl.text.trim(),
      limitBytesTotal: bytes,
    );

    try {
      await ref.read(mikrotikProvider).addHotspotUser(user);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'HOTSPOT ACCESS NODE',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 10)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CyberTextField(
                        controller: _nameCtrl,
                        label: 'اسم المستخدم',
                        icon: Icons.person_outline_rounded,
                        enabled: !_busy,
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'أدخل اسم المستخدم';
                          }
                          if ((v ?? '').contains(' ')) {
                            return 'بدون مسافات';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'توليد تلقائي',
                      color: AppColors.primary,
                      onPressed: _busy
                          ? null
                          : () => setState(
                                () => _nameCtrl.text = _randomString(6),
                              ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CyberTextField(
                        controller: _passCtrl,
                        label: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        isPassword: _obscure,
                        enabled: !_busy,
                        validator: (v) {
                          if ((v ?? '').isEmpty) {
                            return 'أدخل كلمة المرور';
                          }
                          return null;
                        },
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'توليد تلقائي',
                      color: AppColors.primary,
                      onPressed: _busy
                          ? null
                          : () => setState(
                                () => _passCtrl.text = _randomString(4),
                              ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              children: [
                CyberTextField(
                  controller: _profileCtrl,
                  label: 'البروفايل',
                  icon: Icons.category_outlined,
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                CyberTextField(
                  controller: _commentCtrl,
                  label: 'تعليق (اختياري)',
                  icon: Icons.comment_outlined,
                  enabled: !_busy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              children: [
                CyberTextField(
                  controller: _uptimeCtrl,
                  label: 'مدة الصلاحية (اختياري)',
                  icon: Icons.timer_outlined,
                  hint: 'مثال: 1d أو 12h أو 30m',
                  helper: 'اتركه فارغاً لصلاحية غير محدودة',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                CyberTextField(
                  controller: _bytesCtrl,
                  label: 'حد التحميل بالبايت (اختياري)',
                  icon: Icons.data_usage_outlined,
                  hint: 'مثال: 1073741824 = 1GB',
                  keyboardType: TextInputType.number,
                  enabled: !_busy,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.danger.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: _busy ? 'جاري الحفظ...' : 'حفظ المستخدم',
              icon: Icons.check_rounded,
              loading: _busy,
              onPressed: _save,
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}