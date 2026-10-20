import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../core/api/connection_diagnostics.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/connection_provider.dart';
import '../app_shell.dart';

class RouterLoginScreen extends StatefulWidget {
  const RouterLoginScreen({super.key});

  @override
  State<RouterLoginScreen> createState() => _RouterLoginScreenState();
}

class _RouterLoginScreenState extends State<RouterLoginScreen> {
  static const _storage = FlutterSecureStorage();
  final _ip = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();
  bool _remember = false;
  bool _loading = false;
  bool _hidePassword = true;
  List<DiagStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: 'router_ip'),
        _storage.read(key: 'router_port'),
        _storage.read(key: 'router_username'),
        _storage.read(key: 'router_password'),
      ]);
      if (!mounted) return;
      setState(() {
        _ip.text = values[0] ?? '';
        _port.text = values[1] ?? '';
        _user.text = values[2] ?? 'admin';
        if (values[3] != null) _pass.text = values[3]!;
        _remember = values[3] != null;
      });
    } catch (_) {
      // The screen remains usable if secure-storage restoration is unavailable.
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;
    final host = _ip.text.trim();
    final username = _user.text.trim();
    final password = _pass.text;
    final portText = _port.text.trim();
    final port = portText.isEmpty ? null : int.tryParse(portText);

    if (host.isEmpty || username.isEmpty || password.isEmpty ||
        (portText.isNotEmpty && (port == null || port < 1 || port > 65535))) {
      setState(() => _steps = [
        const DiagStep(
          'راجع البيانات',
          false,
          'أدخل عنوان الراوتر واسم المستخدم وكلمة المرور. اترك المنفذ فارغًا للاكتشاف التلقائي.',
        ),
      ]);
      return;
    }

    setState(() {
      _loading = true;
      _steps = [];
    });

    try {
      final result = await ConnectionDiagnostics.run(
        host: host,
        user: username,
        pass: password,
        customPort: port,
      );
      if (!mounted) {
        result.client?.close();
        return;
      }
      setState(() => _steps = result.steps);
      final client = result.client;
      if (!result.success || client == null) return;

      final connection = context.read<ConnectionProvider>();
      await connection.useClient(
        client: client,
        host: host,
        username: username,
        password: password,
        https: client.https,
        port: client.port,
      );

      await _storage.write(key: 'router_ip', value: host);
      await _storage.write(key: 'router_port', value: portText);
      await _storage.write(key: 'router_username', value: username);
      if (_remember) {
        await _storage.write(key: 'router_password', value: password);
      } else {
        await _storage.delete(key: 'router_password');
      }

      if (!mounted) return;
      if (connection.isConnected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppShell()),
        );
      } else {
        setState(() => _steps = [
          ..._steps,
          DiagStep('تحميل بيانات الراوتر', false, connection.errorMessage),
        ]);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _steps = [
          ..._steps,
          DiagStep('الاتصال', false, 'تعذر إكمال الاتصال: $error'),
        ]);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: NovaColors.muted),
        suffixIcon: suffix,
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool secret = false,
    TextInputType keyboard = TextInputType.text,
    TextInputAction action = TextInputAction.next,
  }) =>
      TextField(
        controller: controller,
        obscureText: secret && _hidePassword,
        keyboardType: keyboard,
        textInputAction: action,
        autocorrect: false,
        enableSuggestions: !secret,
        style: const TextStyle(color: NovaColors.text, fontWeight: FontWeight.w600),
        decoration: _decoration(
          label,
          icon,
          hint: label == 'عنوان الراوتر أو IP' ? '192.168.88.1' : null,
          suffix: secret
              ? IconButton(
                  tooltip: _hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: NovaColors.muted,
                  ),
                )
              : null,
        ),
        onSubmitted: action == TextInputAction.done ? (_) => _connect() : null,
      );

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -100,
            right: -80,
            child: _GlowOrb(size: 260, color: Color(0x403A2F77)),
          ),
          const Positioned(
            bottom: -130,
            left: -90,
            child: _GlowOrb(size: 280, color: Color(0x20256B8A)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [NovaColors.primary, Color(0xFF5F55C8)],
                            ),
                            borderRadius: BorderRadius.circular(27),
                            boxShadow: [
                              BoxShadow(
                                color: NovaColors.primary.withOpacity(.25),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.hub_rounded, size: 43, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'NOVA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w900,
                          color: NovaColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'إدارة الشبكة بوضوح وسيطرة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NovaColors.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: NovaColors.surface.withOpacity(.97),
                          border: Border.all(color: NovaColors.border),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'الاتصال بالراوتر',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'أدخل بيانات إدارة MikroTik للوصول إلى أدوات الشبكة.',
                              style: TextStyle(color: NovaColors.muted, height: 1.5),
                            ),
                            const SizedBox(height: 22),
                            _field(_ip, 'عنوان الراوتر أو IP', Icons.router_outlined,
                                keyboard: TextInputType.url),
                            const SizedBox(height: 13),
                            _field(_user, 'اسم المستخدم', Icons.person_outline_rounded),
                            const SizedBox(height: 13),
                            _field(_pass, 'كلمة المرور', Icons.lock_outline_rounded,
                                secret: true, action: TextInputAction.done),
                            const SizedBox(height: 13),
                            _field(_port, 'المنفذ (اختياري)', Icons.settings_ethernet_rounded,
                                keyboard: TextInputType.number,
                                action: TextInputAction.done),
                            const SizedBox(height: 4),
                            CheckboxListTile(
                              value: _remember,
                              onChanged: (value) => setState(() => _remember = value ?? false),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: NovaColors.primary,
                              title: const Text('تذكّر بيانات الراوتر',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              subtitle: const Text(
                                'تُحفظ كلمة المرور فقط عند تفعيل هذا الخيار',
                                style: TextStyle(color: NovaColors.muted, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 9),
                            FilledButton.icon(
                              onPressed: _loading || connection.isLoading ? null : _connect,
                              icon: _loading || connection.isLoading
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                _loading || connection.isLoading
                                    ? 'جارٍ فحص الاتصال...'
                                    : 'اتصال آمن',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_steps.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: NovaColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: NovaColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('نتيجة الاتصال',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 12),
                              for (final step in _steps)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        step.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                                        color: step.ok ? NovaColors.success : NovaColors.danger,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(step.title,
                                                style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 3),
                                            Text(step.detail,
                                                style: const TextStyle(
                                                    color: NovaColors.muted, height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'للوصول من خارج الشبكة استخدم VPN مثل WireGuard، ولا تفتح منفذ الإدارة مباشرة على الإنترنت.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NovaColors.muted, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      );
}