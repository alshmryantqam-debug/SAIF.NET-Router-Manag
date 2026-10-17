import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/router_config.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class RoutersListScreen extends ConsumerWidget {
  const RoutersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routersAsync = ref.watch(savedRoutersProvider);
    final conn = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('الراوترات المحفوظة'),
        backgroundColor: AppColors.bgCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(savedRoutersProvider),
          ),
        ],
      ),
      body: routersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: const TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (routers) {
          if (routers.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                const Icon(
                  Icons.router_outlined,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'لا يوجد راوترات محفوظة',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'اتصل براوتر واحفظ بياناته',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('اتصال براوتر جديد'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routers.length,
            itemBuilder: (_, i) {
              final r = routers[i];
              final isActive = conn.activeProfile?.id == r.id;
              return _buildTile(context, ref, r, isActive);
            },
          );
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    RouterProfile r,
    bool isActive,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withOpacity(0.6)
              : AppColors.border,
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            Icons.router_rounded,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            size: 22,
          ),
        ),
        title: Text(
          r.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${r.host} · ${r.version.label}${r.useSsl ? " · SSL" : ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'نشط',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              onPressed: () => _confirmDelete(context, ref, r),
            ),
          ],
        ),
        onTap: () async {
          if (isActive) return;

          final notifier = ref.read(connectionProvider.notifier);
          final ok = await notifier.connect(r);
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم الاتصال بـ ${r.displayName}'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RouterProfile r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الراوتر'),
        content: Text('هل تريد حذف "${r.displayName}"؟'),
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await ref.read(storageProvider).delete(r.id);
    ref.invalidate(savedRoutersProvider);
  }
}