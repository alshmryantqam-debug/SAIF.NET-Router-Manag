import 'package:flutter/material.dart';
import '../theme.dart';
import 'auth/app_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppLoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.router, size: 100, color: AppTheme.primaryPurple),
            const SizedBox(height: 20),
            Text('نوڨا', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 10),
            const Text('Nova Management', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: AppTheme.primaryPurple),
          ],
        ),
      ),
    );
  }
}
