import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipController = TextEditingController(text: '192.168.88.1');
  final _portController = TextEditingController(text: '443');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<ConnectionProvider>();
    final connected = await provider.connectToRouter(
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text,
    );

    if (!mounted) return;
    if (connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage.isEmpty
              ? 'تعذر الاتصال بالراوتر.'
              : provider.errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                useGradient: true,
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.router_rounded,
                      size: 58,
                      color: AppTheme.primaryPurple,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NOVA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اتصال آمن وإدارة راوتر MikroTik',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'عنوان IP أو اسم المضيف',
                        hintText: '192.168.88.1',
                        prefixIcon: Icon(Icons.dns_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'منفذ HTTPS / REST',
                        hintText: '443',
                        prefixIcon: Icon(Icons.settings_ethernet),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _userController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'اسم مستخدم MikroTik',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (!connection.isLoading) _connect();
                      },
                    ),
                    if (connection.errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        connection.errorMessage,
                        style: const TextStyle(color: AppTheme.dangerRed),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: connection.isLoading ? null : _connect,
                        icon: connection.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_rounded),
                        label: Text(
                          connection.isLoading
                              ? 'جارٍ التحقق من الراوتر...'
                              : 'اتصال بالراوتر',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'استخدم اتصال الإدارة المحلي الموثوق فقط عند استخدام شهادة ذاتية.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
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
}
