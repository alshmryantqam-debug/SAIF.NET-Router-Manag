import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/subscribers_provider.dart';

class AddPppoeScreen extends StatefulWidget {
  const AddPppoeScreen({super.key});

  @override
  State<AddPppoeScreen> createState() => _AddPppoeScreenState();
}

class _AddPppoeScreenState extends State<AddPppoeScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _profileController = TextEditingController(text: 'default');
  bool _saving = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _userController.text.trim();
    final password = _passController.text;
    final profile = _profileController.text.trim();
    if (username.isEmpty || password.isEmpty || profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة اسم المستخدم وكلمة المرور والباقة')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SubscribersProvider>().add(name: username, password: password, profile: profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المشترك بنجاح'), backgroundColor: AppTheme.successGreen));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة المشترك: $e'), backgroundColor: AppTheme.dangerRed));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('إضافة مشترك جديد'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _userController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم (PPPoE)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _profileController,
              decoration: const InputDecoration(
                labelText: 'الباقة (Profile)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ المشترك', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}