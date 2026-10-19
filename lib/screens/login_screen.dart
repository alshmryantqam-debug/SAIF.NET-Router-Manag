import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/router_config.dart';
import '../providers/connection_provider.dart';
import '../widgets/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipController = TextEditingController(text: '192.168.88.1');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 60, color: AppTheme.primaryPurple),
              const SizedBox(height: 20),
              const Text('تسجيل الدخول للراوتر', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'IP الراوتر', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () {
                    final config = MikrotikConfig(
                      id: '1', name: 'Router', ipAddress: _ipController.text,
                      username: _userController.text, password: _passController.text,
                    );
                    context.read<ConnectionProvider>().connect(config);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
                  },
                  child: const Text('دخول', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
