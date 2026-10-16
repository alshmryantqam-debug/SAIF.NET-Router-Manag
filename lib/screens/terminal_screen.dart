import 'package:flutter/material.dart';

import '../theme.dart';

/// Terminal is intentionally disabled to protect the router.
class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDeep,
        appBar: AppBar(title: const Text('الطرفية الآمنة')),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 36, color: AppTheme.warning),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'الطرفية معطّلة لحماية الراوتر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SAIF.NET لا ينفّذ أوامر RouterOS حرة. التغييرات تمر عبر نماذج منظمة (Safe Apply) مع معاينة وموافقة صريحة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.55, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoTile(Icons.monitor_heart_rounded, 'مراقبة الشبكة', 'استخدم مركز التشخيص لقراءة الواجهات والجلسات والسجلات.'),
              _infoTile(Icons.enhanced_encryption_rounded, 'النسخ المشفّرة', 'احفظ تصدير RouterOS محلياً بتشفير AES-256-GCM.'),
              _infoTile(Icons.verified_user_rounded, 'TLS إلزامي', 'الاتصال غير المشفّر يتطلب تحذيراً وموافقة صريحة في كل مرة.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
