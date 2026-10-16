import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);
    final resourceAsync = ref.watch(resourceProvider);
    final service = ref.watch(mikrotikProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          title: 'معلومات الاتصال',
          icon: Icons.lan_outlined,
          children: [
            _row('الحالة', service.isConnected ? 'متصل' : 'غير متصل',
                valueColor: service.isConnected ? AppTheme.success : AppTheme.danger),
            _row('البروتوكول', service.activeProtocol ?? '—'),
            _row('اسم الراوتر', identityAsync.valueOrNull?['name']?.toString() ?? '—'),
            _row('الإصدار', resourceAsync.valueOrNull?['version']?.toString() ?? '—'),
            _row('اللوحة', resourceAsync.valueOrNull?['board-name']?.toString() ?? '—'),
            _row('الجهوزية', resourceAsync.valueOrNull?['uptime']?.toString() ?? '—'),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: 'عن التطبيق',
          icon: Icons.info_outline,
          children: const [
            _StaticRow(label: 'التطبيق', value: 'SAIF.NET Router Manager'),
            _StaticRow(label: 'الإصدار', value: '1.1.0 ULTRA'),
            _StaticRow(label: 'الوضع', value: 'مراقبة + أدوات آمنة'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  title: const Text('قطع الاتصال', style: TextStyle(color: AppTheme.textPrimary)),
                  content: const Text('هل تريد قطع الاتصال بالراوتر والعودة لشاشة الدخول؟',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('قطع الاتصال', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await service.disconnect();
              ref.read(connectedProvider.notifier).state = false;
              ref.invalidate(resourceProvider);
              ref.invalidate(identityProvider);
              ref.invalidate(hotspotUsersProvider);
              ref.invalidate(pppUsersProvider);
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            label: const Text('قطع الاتصال',
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: valueColor ?? AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _StaticRow extends StatelessWidget {
  final String label;
  final String value;
  const _StaticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
