import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/hotspot_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class HotspotScreen extends ConsumerStatefulWidget {
  const HotspotScreen({super.key});

  @override
  ConsumerState<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends ConsumerState<HotspotScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showActiveOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HotspotUser> _filter(List<HotspotUser> users) {
    var list = users;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.comment.toLowerCase().contains(q) ||
              u.profile.toLowerCase().contains(q))
          .toList();
    }
    if (_showActiveOnly) {
      final actives = ref.read(hotspotActiveProvider).valueOrNull ?? [];
      final names = actives
          .map((e) => e['user']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
      list = list.where((u) => names.contains(u.name)).toList();
    }
    return list;
  }

  Future<void> _refresh() async {
    ref.invalidate(hotspotUsersProvider);
    ref.invalidate(hotspotActiveProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _remove(HotspotUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل تريد حذف "${user.name}"؟\nلا يمكن التراجع.'),
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

    if (confirmed != true) return;

    try {
      await ref.read(mikrotikProvider).removeHotspotUser(user.id);
      ref.invalidate(hotspotUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف: ${user.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ref.invalidate(hotspotUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'فشل الحذف: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggle(HotspotUser user, bool enabled) async {
    try {
      await ref
          .read(mikrotikProvider)
          .setHotspotUserDisabled(user.id, !enabled);
      ref.invalidate(hotspotUsersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'فشل: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(hotspotUsersProvider);
    final activeAsync = ref.watch(hotspotActiveProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو التعليق...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'الكل',
                  selected: !_showActiveOnly,
                  onTap: () => setState(() => _showActiveOnly = false),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'النشطون',
                  selected: _showActiveOnly,
                  onTap: () => setState(() => _showActiveOnly = true),
                  badge: activeAsync.valueOrNull?.length ?? 0,
                ),
                const Spacer(),
                if (usersAsync.hasValue)
                  Text(
                    '${_filter(usersAsync.value!).length} مستخدم',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              child: usersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (e, _) => _errorView(e),
                data: (users) {
                  final filtered = _filter(users);
                  if (filtered.isEmpty) return _emptyView();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildTile(filtered[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await context.push<bool>('/hotspot/add');
          if (added == true) {
            ref.invalidate(hotspotUsersProvider);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'مستخدم جديد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppDurations.normal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null && badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: selected
                        ? AppColors.bgDeep
                        : AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTile(HotspotUser user) {
    final disabled = user.disabled;

    return Dismissible(
      key: ValueKey('user-${user.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.25),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.delete_rounded,
          color: AppColors.danger,
          size: 26,
        ),
      ),
      confirmDismiss: (_) async {
        await _remove(user);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: disabled
                ? AppColors.danger.withOpacity(0.35)
                : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: disabled
                      ? AppColors.danger.withOpacity(0.14)
                      : AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  disabled
                      ? Icons.person_off_rounded
                      : Icons.wifi_rounded,
                  color: disabled ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.profile,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (user.password.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${user.password}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (user.comment.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تعديل المستخدم',
                icon: const Icon(Icons.edit_rounded, size: 19),
                color: AppColors.primary,
                onPressed: () async {
                  final saved = await context.push<bool>(
                    '/hotspot/edit',
                    extra: user,
                  );
                  if (saved == true) {
                    ref.invalidate(hotspotUsersProvider);
                    ref.invalidate(hotspotActiveProvider);
                  }
                },
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: !disabled,
                  onChanged: (v) => _toggle(user, v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.wifi_off_rounded,
          size: 64,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _query.isEmpty
                ? (_showActiveOnly
                    ? 'لا يوجد مستخدمون نشطون الآن'
                    : 'لا يوجد مستخدمون')
                : 'لا توجد نتائج للبحث',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'اضغط + لإضافة مستخدم جديد',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
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
        const SizedBox(height: 20),
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
}