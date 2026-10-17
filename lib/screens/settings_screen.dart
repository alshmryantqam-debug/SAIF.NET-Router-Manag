import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);
    final identityAsync = ref.watch(identityProvider);
    final resourceAsync = ref.watch(systemResourceProvider);
    final service = ref.watch(mikrotikProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _card(
          title: 'معلومات الاتصال',
          icon: Icons.lan_outlined,
          children: [
            _row(
              'الحالة',
              conn.isConnected ? 'متصل' : 'غير متصل',
              valueColor: conn.isConnected
                  ? AppColors.success
                  : AppColors.danger,
            ),
            _row('البروتوكول', service.activeProtocol?.label ?? '—'),
            _row(
              'اسم الراوتر',
              identityAsync.valueOrNull ??
                  conn.activeProfile?.displayName ??
                  '—',
            ),
            _row(
              'الإصدار',
              resourceAsync.valueOrNull?.version ?? '—',
            ),
            _row(
              'اللوحة',
              resourceAsync.valueOrNull?.boardName ?? '—',
            ),
            _row(
              'الجهوزية',
              resourceAsync.valueOrNull?.uptime ?? '—',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: 'عن التطبيق',
          icon: Icons.info_outline_rounded,
          children: const [
            _StaticRow(label: 'التطبيق', value: 'TikPlus ULTRA'),
            _StaticRow(label: 'الإصدار', value: 'v1.0.0'),
            _StaticRow(label: 'التقنية', value: 'Flutter + Riverpod'),
            _StaticRow(label: 'الوضع', value: 'إدارة كاملة'),
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
                  title: const Text('قطع الاتصال'),
                  content: const Text(
                    'هل تريد قطع الاتصال بالراوتر والعودة لشاشة الدخول؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('قطع الاتصال'),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              await ref.read(connectionProvider.notifier).disconnect();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
            ),
            label: const Text(
              'قطع الاتصال',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}