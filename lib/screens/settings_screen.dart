import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/subscribers_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';
import 'auth/app_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    final subscribers = context.watch<SubscribersProvider>();
    return Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: RefreshIndicator(
      onRefresh: c.fetchSystemResource,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        GlassCard(useGradient: true, useBlur: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('الراوتر الحالي'),
          Row(children: [const Icon(Icons.router, size: 34, color: NovaColors.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.routerIdentity.isEmpty ? 'لا يوجد راوتر متصل' : c.routerIdentity, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6), StatusPill(c.isConnected ? 'متصل' : 'مقطوع', c.isConnected ? NovaColors.success : NovaColors.danger),
          ]))]),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: c.isConnected ? () async {
            await HapticFeedback.lightImpact();
            final confirm = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('قطع الاتصال؟'), content: const Text('ستُغلق جلسة الراوتر الحالية.'), actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('قطع الاتصال')),
            ]));
            if (confirm != true || !context.mounted) return;
            context.read<ConnectionProvider>().disconnect();
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const AppLoginScreen()), (_) => false);
          } : null, icon: const Icon(Icons.link_off), label: const Text('قطع الاتصال بالراوتر'))),
        ])),
        const SizedBox(height: 12),
        GlassCard(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: NovaColors.primary),
            title: const Text('مزامنة جدولة الانتهاء'),
            subtitle: const Text('إعادة إنشاء مواعيد انتهاء الاشتراكات المستقبلية على الراوتر'),
            enabled: c.isConnected && !subscribers.loading,
            onTap: () async {
              try {
                final count = await context.read<SubscribersProvider>().syncExpirySchedules();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت مزامنة جدولة الانتهاء لـ $count مشترك')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت مزامنة الجدولة: $e')));
              }
            },
          ),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.palette_outlined, color: NovaColors.primary), title: const Text('تغيير رمز التطبيق'), subtitle: const Text('يتطلب تغيير أيقونة التشغيل بناء نسخة جديدة'), onTap: () async { await HapticFeedback.lightImpact(); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تغيير الأيقونة يتطلب تحديث ملفات بناء Android.'))); }),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.history, color: NovaColors.primary), title: const Text('سجل الاتصال'), subtitle: const Text('أحداث الخطوط تظهر في لوحة الرئيسية'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('افتح الرئيسية ثم قسم آخر الأحداث.')))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.info_outline, color: NovaColors.primary), title: const Text('حول التطبيق'), subtitle: const Text('SAIF.NET Router Manager'), onTap: () => showAboutDialog(context: context, applicationName: 'SAIF.NET Router Manager', applicationVersion: '1.0.0', applicationIcon: const Icon(Icons.shield_rounded, size: 40, color: NovaColors.violet), children: const [Text('لوحة عربية لإدارة ومراقبة أجهزة MikroTik.')]))
        ])),
      ]),
    ));
  }
}
