import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/glass_card.dart';
import '../../theme.dart';
import '../dashboard_screen.dart';

class RouterLoginScreen extends StatefulWidget {
  const RouterLoginScreen({Key? key}) : super(key: key);

  @override
  State<RouterLoginScreen> createState() => _RouterLoginScreenState();
}

class _RouterLoginScreenState extends State<RouterLoginScreen> {
  final _ipController = TextEditingController(text: '192.168.88.1');
  final _portController = TextEditingController(text: '443');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  Future<void> _connect() async {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    FocusScope.of(context).unfocus();

    bool success = await provider.connectToRouter(
      ip: _ipController.text.trim(),
      port: _portController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text,
    );

    if (!mounted) return;

    if (success) {
      _showCustomSnackBar('تم الاتصال بنجاح: ${provider.routerIdentity}', AppTheme.successColor, Icons.check_circle);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    } else {
      _showCustomSnackBar(provider.errorMessage, AppTheme.dangerColor, Icons.error_outline);
    }
  }

  void _showCustomSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Cairo'))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 0,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.8)),
          filled: true,
          fillColor: const Color(0xFF121727),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.router_outlined, size: 64, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 24),
                const Text('الاتصال بالراوتر', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('أدخل بيانات الاعتماد (REST API)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInputField(controller: _ipController, label: 'الـ IP', icon: Icons.wifi, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _buildInputField(controller: _portController, label: 'المنفذ', icon: Icons.numbers, keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      _buildInputField(controller: _userController, label: 'اسم المستخدم', icon: Icons.person_outline),
                      _buildInputField(controller: _passController, label: 'كلمة المرور', icon: Icons.lock_outline, isPassword: true),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: provider.isLoading ? null : _connect,
                          child: provider.isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('اتصال آمن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
