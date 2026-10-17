import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/live_chart.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _timer;
  final List<double> _cpuHistory = <double>[];
  final List<double> _ramHistory = <double>[];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(systemResourceProvider);
      ref.invalidate(hotspotActiveProvider);
      ref.invalidate(pppoeActiveProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(systemResourceProvider);
    ref.invalidate(identityProvider);
    ref.invalidate(hotspotUsersProvider);
    ref.invalidate(hotspotActiveProvider);
    ref.invalidate(pppoeUsersProvider);
    ref.invalidate(pppoeActiveProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final resourceAsync = ref.watch(systemResourceProvider);
    final identityAsync = ref.watch(identityProvider);
    final hotspotActiveAsync = ref.watch(hotspotActiveProvider);
    final pppoeActiveAsync = ref.watch(pppoeActiveProvider);
    final conn = ref.watch(connectionProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: resourceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _errorView(e),
        data: (resource) {
          final identity = identityAsync.valueOrNull ?? 'الراوتر';

          if (_cpuHistory.length > 40) _cpuHistory.removeAt(0);
          _cpuHistory.add(resource.cpuLoad.toDouble());
          if (_ramHistory.length > 40) _ramHistory.removeAt(0);
          _ramHistory.add(resource.memUsedPercent);

          final activeHotspot = hotspotActiveAsync.valueOrNull?.length ?? 0;
          final activePppoe = pppoeActiveAsync.valueOrNull?.length ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(
                identity: identity,
                latency: conn.result?.latencyMs ?? 0,
                protocol: conn.result?.protocol.label ?? '—',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'المعالج',
                      value: '${resource.cpuLoad}',
                      unit: '%',
                      icon: Icons.memory_rounded,
                      color: resource.cpuLoad > 80
                          ? AppColors.danger
                          : resource.cpuLoad > 50
                              ? AppColors.warning
                              : AppColors.primary,
                      progress: resource.cpuLoad / 100,
                      subtitle: '${resource.cpuCount} نواة',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'الذاكرة',
                      value: resource.memUsedPercent.toStringAsFixed(0),
                      unit: '%',
                      icon: Icons.storage_rounded,
                      color: resource.memUsedPercent > 80
                          ? AppColors.danger
                          : AppColors.secondary,
                      progress: resource.memUsedPercent / 100,
                      subtitle: _fmtBytes(resource.totalMemory),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Hotspot نشط',
                      value: '$activeHotspot',
                      icon: Icons.wifi_rounded,
                      color: AppColors.success,
                      onTap: () => context.go('/hotspot'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'PPPoE نشط',
                      value: '$activePppoe',
                      icon: Icons.cable_rounded,
                      color: AppColors.accent,
                      onTap: () => context.go('/pppoe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LiveChart(
                values: _cpuHistory,
                color: AppColors.primary,
                title: 'استهلاك المعالج (آخر 40 قراءة)',
                unit: '%',
                maxY: 100,
              ),
              const SizedBox(height: 14),
              LiveChart(
                values: _ramHistory,
                color: AppColors.secondary,
                title: 'استهلاك الذاكرة',
                unit: '%',
                maxY: 100,
              ),
              const SizedBox(height: 18),
              _buildDeviceCard(resource),
              const SizedBox(height: 14),
              _buildQuickActions(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required String identity,
    required int latency,
    required String protocol,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primary.withOpacity(0.3),
      glowColor: AppColors.primary.withOpacity(0.15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.router_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        protocol,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${latency}ms',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.success.withOpacity(0.4),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: AppColors.success,
                ),
                SizedBox(width: 5),
                Text(
                  'متصل',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(SystemResource r) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'معلومات الجهاز',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('اللوحة', r.boardName.isEmpty ? '—' : r.boardName),
          _infoRow('المعمارية', r.architecture.isEmpty ? '—' : r.architecture),
          _infoRow('الإصدار', r.version.isEmpty ? '—' : r.version),
          _infoRow('الجهوزية', r.uptime.isEmpty ? '—' : r.uptime),
          _infoRow(
            'تردد المعالج',
            r.cpuFrequency > 0 ? '${r.cpuFrequency} MHz' : '—',
          ),
          _infoRow(
            'HDD متاح',
            r.totalHdd > 0
                ? '${_fmtBytes(r.freeHdd)} / ${_fmtBytes(r.totalHdd)}'
                : '—',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = <_QuickAction>[
      _QuickAction('Hotspot', Icons.wifi_rounded, AppColors.primary,
          () => context.go('/hotspot')),
      _QuickAction('PPPoE', Icons.cable_rounded, AppColors.secondary,
          () => context.go('/pppoe')),
      _QuickAction('كروت', Icons.confirmation_number_rounded,
          AppColors.accent, () => context.go('/voucher')),
      _QuickAction('Terminal', Icons.terminal_rounded, AppColors.warning,
          () => context.push('/terminal')),
      _QuickAction('واجهات', Icons.lan_rounded, AppColors.success,
          () => context.push('/interfaces')),
      _QuickAction('جدار', Icons.security_rounded, AppColors.danger,
          () => context.push('/firewall')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 10),
          child: Text(
            'وصول سريع',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final a = actions[i];
            return GlassCard(
              padding: const EdgeInsets.all(10),
              borderColor: a.color.withOpacity(0.3),
              onTap: a.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.color.withOpacity(0.14),
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(a.icon, color: a.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _errorView(Object e) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.cloud_off_rounded,
          size: 64,
          color: AppColors.danger,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'فشل تحميل البيانات',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          e.toString().replaceAll('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ),
      ],
    );
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

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}