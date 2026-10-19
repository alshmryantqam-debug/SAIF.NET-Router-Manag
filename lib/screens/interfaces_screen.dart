import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../services/mikrotik_service.dart';
import '../theme.dart';

class InterfacesScreen extends ConsumerWidget {
  const InterfacesScreen({super.key});

  Future<void> _toggleInterface(BuildContext context, WidgetRef ref, InterfaceInfo iface) async {
    final disable = !iface.disabled;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(disable ? 'تعطيل الواجهة' : 'تشغيل الواجهة'),
        content: Text(
          'الواجهة: ${iface.name}\\n'
          '${disable ? "قد يؤدي تعطيلها إلى قطع الإنترنت عن المشتركين أو فقدان اتصال الإدارة." : "سيتم تفعيل الواجهة على الراوتر."}\\n\\n'
          'لا تتابع إلا إذا تأكدت من اختيار الواجهة الصحيحة، ولديك نسخة احتياطية وطريقة وصول بديلة للراوتر.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: disable ? AppColors.danger : AppColors.success),
            child: Text(disable ? 'تعطيل فعلي' : 'تشغيل فعلي'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await ref.read(mikrotikProvider).setInterfaceDisabled(
        iface.id,
        disable,
        explicitlyConfirmed: true,
        backupVerified: true,
        rollbackPlanAvailable: true,
      );
      ref.invalidate(interfacesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(disable ? 'تم إرسال أمر تعطيل ${iface.name}' : 'تم إرسال أمر تشغيل ${iface.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تغيير الواجهة: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ifacesAsync = ref.watch(interfacesProvider);
    final ipsAsync = ref.watch(ipAddressesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('الواجهات'),
        backgroundColor: AppColors.bgCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(interfacesProvider);
              ref.invalidate(ipAddressesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(interfacesProvider);
          ref.invalidate(ipAddressesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(
              'الواجهات',
              Icons.lan_rounded,
              ifacesAsync.valueOrNull?.length ?? 0,
            ),
            const SizedBox(height: 10),
            ifacesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (e, _) => _errBox(e),
              data: (list) {
                if (list.isEmpty) return _emptyBox('لا توجد واجهات');
                return Column(
                  children: list
                      .map((i) => _ifaceTile(i))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            _sectionTitle(
              'عناوين IP',
              Icons.location_on_rounded,
              ipsAsync.valueOrNull?.length ?? 0,
            ),
            const SizedBox(height: 10),
            ipsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (e, _) => _errBox(e),
              data: (list) {
                if (list.isEmpty) return _emptyBox('لا توجد عناوين');
                return Column(
                  children: list
                      .map((i) => _ipTile(i))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
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

  Widget _ifaceTile(InterfaceInfo i) {
    final running = i.running && !i.disabled;
    final color = i.disabled
        ? AppColors.textMuted
        : running
            ? AppColors.success
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _iconForType(i.type),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i.type.isEmpty ? '—' : i.type,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  i.disabled
                      ? 'معطّل'
                      : running
                          ? 'يعمل'
                          : 'متوقف',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: i.disabled ? 'تشغيل الواجهة فعلياً' : 'تعطيل الواجهة فعلياً',
                icon: Icon(
                  i.disabled ? Icons.play_circle_fill_rounded : Icons.power_settings_new_rounded,
                  color: i.disabled ? AppColors.success : AppColors.danger,
                ),
                onPressed: i.id.isEmpty ? null : () => _toggleInterface(context, ref, i),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (i.mac.isNotEmpty)
                _chip(Icons.memory_rounded, i.mac),
              if (i.mtu.isNotEmpty)
                _chip(Icons.straighten_rounded, 'MTU ${i.mtu}'),
              _chip(
                Icons.south_rounded,
                _fmtBytes(i.rxByte),
                color: AppColors.primary,
              ),
              _chip(
                Icons.north_rounded,
                _fmtBytes(i.txByte),
                color: AppColors.secondary,
              ),
            ],
          ),
          if (i.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              i.comment,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ipTile(IpAddressInfo ip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ip.address,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'على: ${ip.interfaceName}'
                  '${ip.dynamic ? " · ديناميكي" : ""}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (ip.disabled)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'معطّل',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: c,
            fontSize: 10.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('ether')) return Icons.cable_rounded;
    if (t.contains('wlan') || t.contains('wifi')) {
      return Icons.wifi_rounded;
    }
    if (t.contains('bridge')) return Icons.hub_rounded;
    if (t.contains('vlan')) return Icons.account_tree_rounded;
    if (t.contains('ppp')) return Icons.settings_input_component;
    if (t.contains('wireguard')) return Icons.vpn_lock_rounded;
    if (t.contains('vpn') || t.contains('l2tp') || t.contains('ovpn')) {
      return Icons.shield_rounded;
    }
    if (t.contains('loopback')) return Icons.loop_rounded;
    return Icons.lan_rounded;
  }

  Widget _errBox(Object e) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Text(
        e.toString().replaceAll('Exception: ', ''),
        style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
        ),
      ),
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