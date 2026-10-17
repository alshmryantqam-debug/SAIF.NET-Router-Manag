import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class FirewallScreen extends ConsumerWidget {
  const FirewallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(firewallRulesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('الجدار الناري'),
        backgroundColor: AppColors.bgCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(firewallRulesProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(firewallRulesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        child: rulesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                e.toString().replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          data: (rules) {
            if (rules.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  const Icon(
                    Icons.security_rounded,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'لا توجد قواعد في الجدار الناري',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            }

            // جروب حسب chain
            final groups = <String, List<FirewallRule>>{};
            for (final r in rules) {
              final key = r.chain.isEmpty ? 'أخرى' : r.chain;
              groups.putIfAbsent(key, () => []).add(r);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statsRow(rules),
                const SizedBox(height: 16),
                ...groups.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _chainHeader(entry.key, entry.value.length),
                      const SizedBox(height: 8),
                      ...entry.value.map((r) => _ruleTile(r)),
                      const SizedBox(height: 16),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statsRow(List<FirewallRule> rules) {
    final disabled = rules.where((r) => r.disabled).length;
    final enabled = rules.length - disabled;
    return Row(
      children: [
        Expanded(
          child: _statBox(
            'قواعد فعّالة',
            '$enabled',
            AppColors.success,
            Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statBox(
            'قواعد معطّلة',
            '$disabled',
            AppColors.textMuted,
            Icons.block_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statBox(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chainHeader(String chain, int count) {
    return Row(
      children: [
        Icon(
          _chainIcon(chain),
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'سلسلة $chain',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  IconData _chainIcon(String chain) {
    switch (chain.toLowerCase()) {
      case 'input':
        return Icons.login_rounded;
      case 'output':
        return Icons.logout_rounded;
      case 'forward':
        return Icons.forward_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  Widget _ruleTile(FirewallRule r) {
    final color = _actionColor(r.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: r.disabled
              ? AppColors.border
              : color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.action.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (r.protocol.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.protocol.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (r.disabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'معطّل',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (r.srcAddress.isNotEmpty ||
              r.dstAddress.isNotEmpty ||
              r.dstPort.isNotEmpty ||
              r.inInterface.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (r.srcAddress.isNotEmpty)
                  _pair('من', r.srcAddress),
                if (r.dstAddress.isNotEmpty)
                  _pair('إلى', r.dstAddress),
                if (r.dstPort.isNotEmpty)
                  _pair('منفذ', r.dstPort),
                if (r.inInterface.isNotEmpty)
                  _pair('دخول', r.inInterface),
                if (r.outInterface.isNotEmpty)
                  _pair('خروج', r.outInterface),
              ],
            ),
          ],
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.comment,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          if (r.bytes > 0 || r.packets > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat(
                  Icons.data_usage_rounded,
                  _fmtBytes(r.bytes),
                ),
                const SizedBox(width: 12),
                _miniStat(
                  Icons.widgets_rounded,
                  '${r.packets} حزمة',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pair(String key, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$key:',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'accept':
        return AppColors.success;
      case 'drop':
        return AppColors.danger;
      case 'reject':
        return AppColors.warning;
      case 'log':
        return AppColors.primary;
      case 'jump':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${units[i]}';
  }
}