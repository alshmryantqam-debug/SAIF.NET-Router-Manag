import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourceAsync = ref.watch(resourceProvider);
    final identityAsync = ref.watch(identityProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(resourceProvider);
        ref.invalidate(identityProvider);
      },
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: resourceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _errorView(e),
        data: (resource) {
          final identity = identityAsync.valueOrNull?['name']?.toString() ?? 'الراوتر';
          final cpu = _number(resource['cpu-load']);
          final freeMem = _number(resource['free-memory']);
          final totalMem = _number(resource['total-memory']);
          final usedMem = totalMem > 0 ? (totalMem - freeMem).clamp(0, totalMem) : 0;
          final memoryPercent = totalMem > 0 ? (usedMem / totalMem * 100).round() : 0;
          final uptime = resource['uptime']?.toString() ?? '—';
          final version = resource['version']?.toString() ?? '—';
          final board = resource['board-name']?.toString() ?? '—';
          final architecture = resource['architecture-name']?.toString() ?? '—';
          final cpuPercent = cpu.clamp(0, 100);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _topHeader(identity),
              const SizedBox(height: 20),
              _heroCard(identity: identity, board: board, version: version),
              const SizedBox(height: 18),
              const _SectionHeading(title: 'صحة الجهاز', subtitle: 'قراءات مباشرة من الراوتر'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'استخدام المعالج',
                      value: '$cpuPercent',
                      unit: '%',
                      icon: Icons.memory_rounded,
                      color: _loadColor(cpuPercent),
                      progress: cpuPercent / 100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: 'الذاكرة المستخدمة',
                      value: '$memoryPercent',
                      unit: '%',
                      icon: Icons.developer_board_rounded,
                      color: _loadColor(memoryPercent),
                      progress: memoryPercent / 100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading(title: 'تفاصيل النظام', subtitle: 'معلومات الجهاز والإصدار'),
                    const SizedBox(height: 16),
                    _InfoRow(icon: Icons.router_rounded, label: 'نوع اللوحة', value: board),
                    _InfoRow(icon: Icons.terminal_rounded, label: 'إصدار RouterOS', value: version),
                    _InfoRow(icon: Icons.schedule_rounded, label: 'مدة التشغيل', value: uptime),
                    _InfoRow(icon: Icons.memory_rounded, label: 'المعمارية', value: architecture),
                    _InfoRow(
                      icon: Icons.storage_rounded,
                      label: 'الذاكرة الحرة',
                      value: _formatBytes(freeMem),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.shield_moon_rounded, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإدارة الآمنة أولاً',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 5),
                          Text(
                            'ستظهر تغييرات الإعدادات كمعاينة مع نسخة احتياطية وموافقة واضحة قبل أي تنفيذ. لا تُنفَّذ تغييرات تلقائية من هذه اللوحة.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _topHeader(String identity) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.secondary, AppTheme.primary]),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(color: AppTheme.secondary.withOpacity(0.25), blurRadius: 22, offset: const Offset(0, 7)),
              ],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SAIF.NET', style: TextStyle(color: AppTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(identity, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.success.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 7, color: AppTheme.success),
                SizedBox(width: 7),
                Text('متصل', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      );

  Widget _heroCard({required String identity, required String board, required String version}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.gradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: AppTheme.secondary.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -10,
              top: -18,
              child: Icon(Icons.blur_on_rounded, size: 120, color: AppTheme.primary.withOpacity(0.07)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 17),
                    const SizedBox(width: 7),
                    Text('مركز التحكم الذكي', style: TextStyle(color: AppTheme.primary.withOpacity(0.95), fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 15),
                Text(identity, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(board, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(icon: Icons.verified_user_outlined, text: 'إدارة محلية'),
                    _Tag(icon: Icons.system_update_alt_rounded, text: 'RouterOS $version'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  Widget _errorView(Object error) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 42, color: AppTheme.danger),
          ),
          const SizedBox(height: 18),
          const Center(child: Text('تعذّر تحميل بيانات الراوتر',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Text(error.toString().replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6)),
          const SizedBox(height: 18),
          const Center(child: Text('اسحب الشاشة للأسفل لإعادة المحاولة',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        ],
      );

  static int _number(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

  static Color _loadColor(int value) {
    if (value >= 85) return AppTheme.danger;
    if (value >= 65) return AppTheme.warning;
    return AppTheme.accent;
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      );
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double progress;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 19),
                ),
                const Spacer(),
                Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted, size: 20),
              ],
            ),
            const SizedBox(height: 15),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 29, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppTheme.bgSurface,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.textMuted, size: 17),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                const SizedBox(width: 12),
                Flexible(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          if (!last) const Divider(height: 1),
        ],
      );
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
