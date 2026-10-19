import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';

class AddPppoeScreen extends StatefulWidget {
  const AddPppoeScreen({super.key});
  @override
  State<AddPppoeScreen> createState() => _AddPppoeScreenState();
}

class _AddPppoeScreenState extends State<AddPppoeScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _profileController = TextEditingController(text: 'default');

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
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم (PPPoE)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _profileController,
              decoration: const InputDecoration(labelText: 'الباقة (Profile)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                onPressed: () {
                  if (_userController.text.isNotEmpty && _passController.text.isNotEmpty) {
                    // هنا يتم استدعاء دالة الإضافة من الـ Provider
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ المشترك', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}