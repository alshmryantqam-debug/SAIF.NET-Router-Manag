import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/glass_card.dart';
import 'router_login_screen.dart';

/// Local app-entry gate. This PIN is a demo fallback, not production
/// authentication; replace it with secure, persisted authentication before
/// distributing the app to other administrators.
class AppLoginScreen extends StatefulWidget {
  const AppLoginScreen({Key? key}) : super(key: key);

  @override
  State<AppLoginScreen> createState() => _AppLoginScreenState();
}

class _AppLoginScreenState extends State<AppLoginScreen> {
  final _pinController = TextEditingController();
  bool _isError = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    if (_pinController.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RouterLoginScreen(),
        ),
      );
      return;
    }

    setState(() => _isError = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                useGradient: true,
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_moon_rounded,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'مرحباً بك في SAIF.NET',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تسجيل دخول مدير الشبكة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'أدخل رمز الوصول للمتابعة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      textAlign: TextAlign.center,
                      onChanged: (_) {
                        if (_isError) setState(() => _isError = false);
                      },
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.backgroundColor.withOpacity(0.5),
                        hintText: '••••',
                        hintStyle:
                            const TextStyle(color: AppTheme.textSecondary),
                        errorText: _isError ? 'رمز الوصول غير صحيح.' : null,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _login,
                        child: const Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تنبيه: رمز 1234 تجريبي فقط ولا يوفر حماية حقيقية.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
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
