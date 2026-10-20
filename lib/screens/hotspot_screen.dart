import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/hotspot_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/cyber_hotspot_card.dart';
import '../widgets/particle_matrix_bg.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'HOTSPOT MATRIX',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
            shadows: [
              Shadow(color: Color(0xFFE040FB), blurRadius: 10),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            onPressed: _refresh,
            icon: const Icon(
              Icons.sync_rounded,
              color: Color(0xFFE040FB),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
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
                    filled: true,
                    fillColor: const Color(0xCC070B14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: const Color(0xFFE040FB).withOpacity(0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: const Color(0xFFE040FB).withOpacity(0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE040FB),
                        width: 1.4,
                      ),
                    ),
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
                  color: const Color(0xFFE040FB),
                  backgroundColor: const Color(0xFF070B14),
                  child: usersAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE040FB),
                      ),
                    ),
                    error: (e, _) => _errorView(e),
                    data: (users) {
                      final filteredUsers = _filter(users);
                      if (filteredUsers.isEmpty) return _emptyView();
                      return ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 120,
                          top: 16,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return CyberHotspotCard(
                            name: user.name,
                            profile: user.profile,
                            limitUptime: user.limitUptime,
                            isDisabled: user.disabled,
                            onToggle: () => _toggle(user, !user.disabled),
                            onDelete: () => _remove(user),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE040FB).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF070B14),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFFE040FB), width: 2),
          ),
          onPressed: () async {
            final added = await context.push<bool>('/hotspot/add');
            if (added == true) {
              ref.invalidate(hotspotUsersProvider);
            }
          },
          child: const Icon(Icons.add, color: Color(0xFFE040FB)),
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
    return CyberHotspotCard(
      name: user.name,
      profile: user.profile,
      limitUptime: user.limitUptime,
      isDisabled: user.disabled,
      onToggle: () => _toggle(user, !user.disabled),
      onDelete: () => _remove(user),
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