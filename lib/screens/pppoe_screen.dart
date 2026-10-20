import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pppoe_user.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/cyber_user_card.dart';
import '../widgets/particle_matrix_bg.dart';

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
    final totalCount = usersAsync.valueOrNull?.length ?? 0;
    final activeCount = activeAsync.valueOrNull?.length ?? 0;
    final visibleCount = usersAsync.valueOrNull == null
        ? 0
        : _filter(usersAsync.value!).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ParticleMatrixBg(
        particleCount: 46,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.55),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PPPoE // NODE CONTROL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'إدارة حسابات الوصول ومراقبة المشتركين',
                          style: TextStyle(
                            color: Color(0xFF9BB2C5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _hudIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'تحديث البيانات',
                    onTap: _refresh,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.20),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      cursorColor: const Color(0xFF00E5FF),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو البروفايل أو IP...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF71889B),
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF00E5FF),
                          size: 20,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                tooltip: 'مسح البحث',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF9BB2C5),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statChip('TOTAL', '$totalCount', const Color(0xFFB18CFF)),
                  const SizedBox(width: 8),
                  _statChip('ACTIVE', '$activeCount', const Color(0xFF00E5FF)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '$visibleCount نتيجة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Color(0xFF8DA9BD),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: const Color(0xFF00E5FF),
                backgroundColor: const Color(0xFF111A2A),
                child: usersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF),
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (e, _) => _errorView(e),
                  data: (users) {
                    final filtered = _filter(users);
                    if (filtered.isEmpty) return _emptyView();
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _buildTile(filtered[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7A43F1),
        foregroundColor: Colors.white,
        onPressed: () async {
          final added = await context.push<bool>('/pppoe/add');
          if (added == true) {
            ref.invalidate(pppoeUsersProvider);
            ref.invalidate(pppoeActiveProvider);
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

  Widget _hudIconButton({
    required IconData icon,
    required String tooltip,
    required Future<void> Function() onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0x1A00E5FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00E5FF).withOpacity(0.35),
            ),
          ),
          child: Icon(icon, color: const Color(0xFF00E5FF), size: 20),
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
    final detailParts = <String>[user.service.toUpperCase()];
    if (user.remoteAddress.isNotEmpty) {
      detailParts.add('IP ' + user.remoteAddress);
    }
    if (user.comment.isNotEmpty) {
      detailParts.add(user.comment);
    }

    return Dismissible(
      key: ValueKey('pppoe-' + user.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withOpacity(0.5)),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
          size: 26,
        ),
      ),
      confirmDismiss: (_) async {
        await _remove(user);
        return false;
      },
      child: CyberUserCard(
        name: user.name,
        profile: user.profile,
        detail: detailParts.join('  •  '),
        isDisabled: user.disabled,
        onToggle: () => _toggle(user, !user.disabled),
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
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