import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pppoe_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/ultra_input.dart';

class AddPppoeScreen extends ConsumerStatefulWidget {
  const AddPppoeScreen({super.key});

  @override
  ConsumerState<AddPppoeScreen> createState() => _AddPppoeScreenState();
}

class _AddPppoeScreenState extends ConsumerState<AddPppoeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _profileCtrl = TextEditingController(text: 'default');
  final _localCtrl = TextEditingController();
  final _remoteCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _service = 'pppoe';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static final Random _rnd = Random.secure();
  static const String _alphabet =
      'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _randomString(int len) =>
      List.generate(len, (_) => _alphabet[_rnd.nextInt(_alphabet.length)])
          .join();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _profileCtrl.dispose();
    _localCtrl.dispose();
    _remoteCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final user = PppoeUser(
      name: _nameCtrl.text.trim(),
      password: _passCtrl.text,
      profile: _profileCtrl.text.trim().isEmpty
          ? 'default'
          : _profileCtrl.text.trim(),
      service: _service,
      localAddress: _localCtrl.text.trim(),
      remoteAddress: _remoteCtrl.text.trim(),
      comment: _commentCtrl.text.trim(),
    );

    try {
      await ref.read(mikrotikProvider).addPppoeUser(user);
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
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('مشترك PPPoE جديد'),
        backgroundColor: AppColors.bgCard,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: UltraInput(
                        controller: _nameCtrl,
                        label: 'اسم المشترك',
                        icon: Icons.person_outline_rounded,
                        enabled: !_busy,
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'أدخل الاسم';
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
                      child: UltraInput(
                        controller: _passCtrl,
                        label: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
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
                                () => _passCtrl.text = _randomString(8),
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
                DropdownButtonFormField<String>(
                  value: _service,
                  decoration: const InputDecoration(
                    labelText: 'نوع الخدمة',
                    prefixIcon: Icon(Icons.settings_input_component),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pppoe',
                      child: Text('PPPoE'),
                    ),
                    DropdownMenuItem(
                      value: 'pptp',
                      child: Text('PPTP'),
                    ),
                    DropdownMenuItem(
                      value: 'l2tp',
                      child: Text('L2TP'),
                    ),
                    DropdownMenuItem(
                      value: 'ovpn',
                      child: Text('OpenVPN'),
                    ),
                    DropdownMenuItem(
                      value: 'any',
                      child: Text('أي'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _service = v ?? 'pppoe'),
                ),
                const SizedBox(height: 12),
                UltraInput(
                  controller: _profileCtrl,
                  label: 'البروفايل',
                  icon: Icons.category_outlined,
                  enabled: !_busy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              children: [
                UltraInput(
                  controller: _localCtrl,
                  label: 'العنوان المحلي (اختياري)',
                  icon: Icons.location_on_outlined,
                  hint: 'مثال: 10.0.0.1',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                UltraInput(
                  controller: _remoteCtrl,
                  label: 'العنوان البعيد (اختياري)',
                  icon: Icons.public_rounded,
                  hint: 'مثال: 10.0.0.100',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                UltraInput(
                  controller: _commentCtrl,
                  label: 'تعليق (اختياري)',
                  icon: Icons.comment_outlined,
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
              label: _busy ? 'جاري الحفظ...' : 'حفظ المشترك',
              icon: Icons.check_rounded,
              loading: _busy,
              onPressed: _save,
            ),
          ],
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