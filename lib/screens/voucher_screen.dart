import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../theme.dart';

class VoucherScreen extends ConsumerStatefulWidget {
  const VoucherScreen({super.key});

  @override
  ConsumerState<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends ConsumerState<VoucherScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(hotspotUsersProvider);

    return Column(
      children: [
        // ═══ Info banner ═══
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'وضع القراءة فقط — عرض المستخدمين ككروت. توليد كروت جديدة يتطلب تفعيل صلاحيات الكتابة.',
                  style: TextStyle(color: AppTheme.warning, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // ═══ Search bar ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'بحث عن مستخدم...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // ═══ Vouchers grid ═══
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (e, _) => _errorView(e),
            data: (users) {
              final filtered = users
                  .cast<Map>()
                  .where((u) {
                    if (_query.isEmpty) return true;
                    final name = (u['name'] ?? '').toString().toLowerCase();
                    final comment =
                        (u['comment'] ?? '').toString().toLowerCase();
                    return name.contains(_query) || comment.contains(_query);
                  })
                  .toList();

              if (filtered.isEmpty) {
                return _emptyView(
                  _query.isEmpty
                      ? 'لا يوجد مستخدمون على الراوتر'
                      : 'لا توجد نتائج للبحث',
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(hotspotUsersProvider),
                color: AppTheme.primary,
                backgroundColor: AppTheme.bgCard,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _VoucherCard(user: filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyView(String message) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );

  Widget _errorView(Object e) => ListView(
        padding: const EdgeInsets.all(24),
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

// ═══════════════════════════════════════════════
//  VOUCHER CARD
// ═══════════════════════════════════════════════
class _VoucherCard extends StatelessWidget {
  final Map user;
  const _VoucherCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final code = user['name']?.toString() ?? '—';
    final password = user['password']?.toString() ?? '—';
    final profile = user['profile']?.toString() ?? 'default';
    final disabled = user['disabled']?.toString() == 'true';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: disabled
              ? [
                  AppTheme.danger.withOpacity(0.15),
                  AppTheme.bgCard,
                ]
              : [
                  AppTheme.primary.withOpacity(0.12),
                  AppTheme.secondary.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: disabled
              ? AppTheme.danger.withOpacity(0.4)
              : AppTheme.primary.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copyToClipboard(context, code, password),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: profile + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      profile,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    disabled
                        ? Icons.block
                        : Icons.check_circle_outline,
                    size: 16,
                    color: disabled
                        ? AppTheme.danger
                        : AppTheme.success,
                  ),
                ],
              ),
              const Spacer(),

              // Code (username)
              Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),

              // Password
              Text(
                password,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),

              const Spacer(),

              // Footer: copy hint
              Row(
                children: [
                  const Icon(
                    Icons.copy,
                    size: 12,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'نسخ',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(
    BuildContext context,
    String code,
    String password,
  ) {
    final text = 'User: $code\nPassword: $password';
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ: $code'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
