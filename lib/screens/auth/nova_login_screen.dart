import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/router_config.dart';
import '../../providers/connection_provider.dart';

const _ink = Color(0xFF080D17);
const _panel = Color(0xCC111B29);
const _cyan = Color(0xFF73E5F2);
const _text = Color(0xFFF1F5F9);
const _muted = Color(0xFF9AA9BA);
const _danger = Color(0xFFFF7888);

class NovaLoginScreen extends ConsumerStatefulWidget {
  const NovaLoginScreen({super.key});

  @override
  ConsumerState<NovaLoginScreen> createState() => _NovaLoginScreenState();
}

class _NovaLoginScreenState extends ConsumerState<NovaLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'الراوتر الرئيسي');
  final _host = TextEditingController(text: '192.168.88.1');
  final _port = TextEditingController(text: '8728');
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  RouterVersion _version = RouterVersion.v6;
  bool _secure = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastRouter();
  }

  Future<void> _restoreLastRouter() async {
    try {
      final profile = await ref.read(storageProvider).getLastUsed();
      if (!mounted || profile == null) return;
      setState(() {
        _name.text = profile.name;
        _host.text = profile.host;
        _username.text = profile.username;
        _password.text = profile.password;
        _version = profile.version;
        _secure = profile.useSsl;
        _port.text = profile.version == RouterVersion.v7
            ? (profile.useSsl ? '443' : '80')
            : (profile.useSsl ? '8729' : '8728');
      });
    } catch (_) {
      // Keep the safe defaults if no saved router exists.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _selectVersion(RouterVersion? value) {
    if (value == null || _busy) return;
    setState(() {
      _version = value;
      if (value == RouterVersion.v7) {
        _secure = true;
        _port.text = '443';
      } else if (value == RouterVersion.v6) {
        _secure = false;
        _port.text = '8728';
      } else {
        _secure = false;
        _port.text = '80';
      }
      _error = null;
    });
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'أدخل رقم منفذ صحيحاً بين 1 و65535');
      return;
    }

    final profile = RouterProfile(
      id: const Uuid().v4(),
      name: _name.text.trim().isEmpty ? host : _name.text.trim(),
      host: host,
      username: _username.text.trim(),
      password: _password.text,
      restPort: _version == RouterVersion.v7 ? port : (_secure ? 443 : 80),
      apiPort: _version == RouterVersion.v6 ? port : (_secure ? 8729 : 8728),
      version: _version,
      useSsl: _secure,
    );

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref.read(connectionProvider.notifier).connect(profile);
      if (!mounted) return;
      if (ok) {
        context.goNamed('dashboard');
      } else {
        setState(() {
          _busy = false;
          _error = ref.read(connectionProvider).error ?? 'تعذر الاتصال بالراوتر؛ تحقق من البيانات والإعدادات.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _ink,
        body: Stack(
          children: [
            const Positioned(top: -120, right: -110, child: _SoftGlow(size: 300, color: Color(0x243BC9E0))),
            const Positioned(bottom: -140, left: -120, child: _SoftGlow(size: 310, color: Color(0x1B8A70E8))),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: _BrandMark(),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'مرحباً بعودتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _text, fontSize: 29, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اتصل براوترك لإدارة شبكتك بأمان',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 14, height: 1.6),
                          ),
                          const SizedBox(height: 28),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _panel,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(.09)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _field(_name, 'اسم الراوتر', Icons.router_rounded),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: _field(
                                            _host,
                                            'عنوان الراوتر',
                                            Icons.lan_rounded,
                                            keyboardType: TextInputType.url,
                                            validator: (value) {
                                              final v = value?.trim() ?? '';
                                              if (v.isEmpty || v.contains(' ')) return 'أدخل عنواناً صحيحاً';
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 4,
                                          child: _field(
                                            _port,
                                            'المنفذ',
                                            Icons.cable_rounded,
                                            keyboardType: TextInputType.number,
                                            formatters: [FilteringTextInputFormatter.digitsOnly],
                                            validator: (value) {
                                              final n = int.tryParse(value ?? '');
                                              if (n == null || n < 1 || n > 65535) return 'غير صالح';
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<RouterVersion>(
                                      value: _version,
                                      dropdownColor: const Color(0xFF152233),
                                      style: const TextStyle(color: _text, fontSize: 14),
                                      decoration: _decoration('إصدار نظام الراوتر', Icons.settings_ethernet_rounded),
                                      items: const [
                                        DropdownMenuItem(value: RouterVersion.auto, child: Text('تحديد تلقائي')),
                                        DropdownMenuItem(value: RouterVersion.v6, child: Text('الإصدار السادس')),
                                        DropdownMenuItem(value: RouterVersion.v7, child: Text('الإصدار السابع')),
                                      ],
                                      onChanged: _busy ? null : _selectVersion,
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: _secure,
                                      onChanged: _busy ? null : (value) => setState(() => _secure = value),
                                      activeColor: _cyan,
                                      title: const Text('اتصال مشفّر', style: TextStyle(color: _text, fontSize: 14)),
                                      subtitle: const Text('فعّله فقط إذا كان مفعّلاً في الراوتر', style: TextStyle(color: _muted, fontSize: 11)),
                                    ),
                                    const SizedBox(height: 8),
                                    _field(_username, 'اسم المستخدم', Icons.person_outline_rounded),
                                    const SizedBox(height: 14),
                                    _field(
                                      _password,
                                      'كلمة المرور',
                                      Icons.lock_outline_rounded,
                                      obscure: _hidePassword,
                                      suffix: IconButton(
                                        tooltip: _hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                        onPressed: _busy ? null : () => setState(() => _hidePassword = !_hidePassword),
                                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _muted, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: _danger.withOpacity(.08),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: _danger.withOpacity(.25)),
                              ),
                              child: Text(_error!, style: const TextStyle(color: _danger, fontSize: 13, height: 1.5)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: _busy ? null : _connect,
                              style: FilledButton.styleFrom(
                                backgroundColor: _cyan,
                                foregroundColor: _ink,
                                disabledBackgroundColor: _cyan.withOpacity(.35),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              child: _busy
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
                                  : const Text('بدء الاتصال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'تُستخدم بيانات الدخول للاتصال بالراوتر الذي تحدده',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: _text, fontSize: 14),
      decoration: _decoration(label, icon).copyWith(suffixIcon: suffix),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: _cyan.withOpacity(.85), size: 20),
        filled: true,
        fillColor: Colors.black.withOpacity(.16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _cyan, width: 1.2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _danger)),
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: _cyan.withOpacity(.3)),
          boxShadow: [BoxShadow(color: _cyan.withOpacity(.08), blurRadius: 24, spreadRadius: 1)],
        ),
        child: const Icon(Icons.hub_rounded, color: _cyan, size: 32),
      );
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
          child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        ),
      );
}
