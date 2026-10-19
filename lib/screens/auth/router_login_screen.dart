import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connection_provider.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../dashboard_screen.dart';

/// شاشة الاتصال المباشر براوتر MikroTik عبر RouterOS REST/HTTPS.
class RouterLoginScreen extends StatefulWidget {
  const RouterLoginScreen({super.key});

  @override
  State<RouterLoginScreen> createState() => _RouterLoginScreenState();
}

class _RouterLoginScreenState extends State<RouterLoginScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final provider = context.read<ConnectionProvider>();

    final success = await provider.connectToRouter(
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successColor,
            content: Text('تم الاتصال بنجاح: ${provider.routerIdentity}'),
          ),
        );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerColor,
            content: Text(
              provider.errorMessage.isEmpty
                  ? 'تعذر الاتصال بالراوتر. تحقق من العنوان والمنفذ وبيانات الدخول.'
                  : provider.errorMessage,
            ),
          ),
        );
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !isPassword,
        style: const TextStyle(color: AppTheme.textPrimary),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          filled: true,
          fillColor: AppTheme.backgroundColor.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.cardBorderColor.withOpacity(0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('الاتصال بالراوتر')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                useGradient: true,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.router_rounded,
                        size: 52,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'الاتصال براوتر MikroTik',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أدخل عنوان الراوتر وبيانات حساب لديه صلاحية API/REST.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              'عنوان IP أو اسم المضيف',
                              _ipController,
                              Icons.router,
                              keyboardType: TextInputType.url,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'أدخل عنوان الراوتر'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              'المنفذ',
                              _portController,
                              Icons.numbers,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final port = int.tryParse(value?.trim() ?? '');
                                if (port == null || port < 1 || port > 65535) {
                                  return 'منفذ غير صالح';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(
                        'اسم المستخدم',
                        _userController,
                        Icons.person_outline,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'أدخل اسم المستخدم'
                                : null,
                      ),
                      _buildTextField(
                        'كلمة المرور',
                        _passController,
                        Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor:
                                AppTheme.primaryColor.withOpacity(0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.link, color: Colors.white),
                          label: Text(
                            provider.isLoading
                                ? 'جارٍ الاتصال...'
                                : 'اتصال مباشر بالراوتر',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'تأكد من تفعيل خدمة www-ssl على الراوتر والسماح بالوصول من جهازك. '
                        'لا تستخدم الاتصال عبر شبكة عامة غير موثوقة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
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
}
