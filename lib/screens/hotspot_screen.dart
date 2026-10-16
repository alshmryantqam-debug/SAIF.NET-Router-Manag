import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class HotspotScreen extends ConsumerWidget {
  const HotspotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(hotspotUsersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(hotspotUsersProvider),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _errorView(e),
        data: (users) {
          if (users.isEmpty) return _emptyView();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i] as Map;
              final name = user['name']?.toString() ?? '—';
              final profile = user['profile']?.toString() ?? 'default';
              final disabled = user['disabled']?.toString() == 'true';
              final comment = user['comment']?.toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: disabled
                        ? AppTheme.danger.withOpacity(0.15)
                        : AppTheme.primary.withOpacity(0.15),
                    child: Icon(
                      disabled ? Icons.person_off : Icons.wifi,
                      color: disabled ? AppTheme.danger : AppTheme.primary,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    comment ?? profile,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: disabled
                          ? AppTheme.danger.withOpacity(0.15)
                          : AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      disabled ? 'معطّل' : 'نشط',
                      style: TextStyle(
                        color: disabled ? AppTheme.danger : AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyView() => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.wifi_off, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'لا يوجد مستخدمون',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'اسحب للأسفل للتحديث',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      );

  Widget _errorView(Object e) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(
            e.toString().replaceAll('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger, fontSize: 14),
          ),
        ],
      );
}
