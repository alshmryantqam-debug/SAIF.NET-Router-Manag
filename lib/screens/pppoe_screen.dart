import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pppoe_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';

class PppoeScreen extends ConsumerStatefulWidget {
  const PppoeScreen({super.key});

  @override
  ConsumerState<PppoeScreen> createState() => _PppoeScreenState();
}

class _PppoeScreenState extends ConsumerState<PppoeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PppoeUser> _filter(List<PppoeUser> users) {
    if (_query.isEmpty) return users;
    final q = _query.toLowerCase();
    return users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.comment.toLowerCase().contains(q) ||
            u.profile.toLowerCase().contains(q) ||
            u.remoteAddress.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(pppoeUsersProvider);
    ref.invalidate(pppoeActiveProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _remove(PppoeUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشترك'),
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
      await ref.read(mikrotikProvider).removePppoeUser(user.id);
      ref.invalidate(pppoeUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف: ${user.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ref.invalidate(pppoeUsersProvider);
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

  Future<void> _toggle(PppoeUser user, bool enabled) async {
    try {
      await ref
          .read(mikrotikProvider)
          .setPppoeUserDisabled(user.id, !enabled);
      ref.invalidate(pppoeUsersProvider);
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
    final usersAsync = ref.watch(pppoeUsersProvider);
    final activeAsync = ref.watch(pppoeActiveProvider);

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
                hintText: 'بحث بالاسم أو العنوان...',
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
                _statChip(
                  'إجمالي',
                  '${usersAsync.valueOrNull?.length ?? 0}',
                  AppColors.primary,
                ),
                const SizedBox(width: 8),
                _statChip(
                  'نشط',
                  '${activeAsync.valueOrNull?.length ?? 0}',
                  AppColors.success,
                ),
                const Spacer(),
                if (usersAsync.hasValue)
                  Text(
                    '${_filter(usersAsync.value!).length} نتيجة',
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
          final added = await context.push<bool>('/pppoe/add');
          if (added == true) {
            ref.invalidate(pppoeUsersProvider);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'مشترك جديد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(PppoeUser user) {
    final disabled = user.disabled;

    return Dismissible(
      key: ValueKey('pppoe-${user.id}'),
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
                      : AppColors.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  disabled
                      ? Icons.person_off_rounded
                      : Icons.cable_rounded,
                  color:
                      disabled ? AppColors.danger : AppColors.secondary,
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
                            user.service,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user.remoteAddress.isEmpty
                                ? user.profile
                                : user.remoteAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
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
                tooltip: 'تعديل المشترك',
                icon: const Icon(Icons.edit_rounded, size: 19),
                color: AppColors.primary,
                onPressed: () async {
                  final saved = await context.push<bool>(
                    '/pppoe/edit',
                    extra: user,
                  );
                  if (saved == true) {
                    ref.invalidate(pppoeUsersProvider);
                    ref.invalidate(pppoeActiveProvider);
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
          Icons.cable_rounded,
          size: 64,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _query.isEmpty
                ? 'لا يوجد مشتركو PPPoE'
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
            'اضغط + لإضافة مشترك جديد',
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