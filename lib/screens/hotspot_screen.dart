import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/nova_theme.dart';
import '../models/hotspot_user.dart';
import '../providers/connection_provider.dart';
import '../providers/hotspot_provider.dart';
import '../widgets/glass_card.dart';

class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HotspotProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String value, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(value),
        backgroundColor: success ? NovaColors.surface2 : NovaColors.danger,
      ));
  }

  Future<void> _generateVouchers(HotspotProvider provider) async {
    final countController = TextEditingController(text: '10');
    final lengthController = TextEditingController(text: '6');
    final profileController = TextEditingController(text: 'default');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء بطاقات جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد البطاقات (1–500)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'طول الرمز (4–16)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: profileController,
              decoration: const InputDecoration(labelText: 'اسم البروفايل'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final count = int.tryParse(countController.text);
              final length = int.tryParse(lengthController.text);
              final profile = profileController.text.trim();
              if (count == null ||
                  count < 1 ||
                  count > 500 ||
                  length == null ||
                  length < 4 ||
                  length > 16 ||
                  profile.isEmpty) {
                _message('تحقق من العدد وطول الرمز واسم البروفايل.', success: false);
                return;
              }
              Navigator.pop(dialogContext);
              _create(count, length, profile, provider);
            },
            child: const Text('إنشاء البطاقات'),
          ),
        ],
      ),
    );

    countController.dispose();
    lengthController.dispose();
    profileController.dispose();
  }

  Future<void> _create(
    int count,
    int length,
    String profile,
    HotspotProvider provider,
  ) async {
    final ok = await provider.generateVouchers(count, profile, length.toString());
    if (!mounted) return;
    _message(
      ok ? 'تم إنشاء $count بطاقة على الراوتر.' : (provider.error ?? 'فشل إنشاء البطاقات.'),
      success: ok,
    );
  }

  Future<void> _editUser(HotspotUser user, HotspotProvider provider) async {
    final nameController = TextEditingController(text: user.name);
    final profileController = TextEditingController(text: user.profile);
    final passwordController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بطاقة هوتسبوت'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'اسم المستخدم / الرمز'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: profileController,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'البروفايل'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                autocorrect: false,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة مرور جديدة (اختياري)',
                  helperText: 'اتركها فارغة للاحتفاظ بكلمة المرور الحالية.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  profileController.text.trim().isEmpty) {
                _message('اسم المستخدم والبروفايل مطلوبان.', success: false);
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final profile = profileController.text.trim();
    final password = passwordController.text;
    nameController.dispose();
    profileController.dispose();
    passwordController.dispose();

    if (accepted != true) return;
    final ok = await provider.updateUser(
      id: user.id,
      name: name,
      profile: profile,
      password: password,
    );
    if (!mounted) return;
    _message(
      ok ? 'تم تعديل البطاقة على الراوتر.' : (provider.error ?? 'تعذر تعديل البطاقة.'),
      success: ok,
    );
  }

  Future<void> _deleteUser(HotspotUser user, HotspotProvider provider) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف البطاقة؟'),
        content: Text('سيتم حذف حساب ${user.name} من الراوتر. لا يمكن التراجع عن هذا الحذف من التطبيق.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NovaColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final ok = await provider.deleteUser(user.id);
    if (!mounted) return;
    _message(
      ok ? 'تم حذف البطاقة من الراوتر.' : (provider.error ?? 'تعذر حذف البطاقة.'),
      success: ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotspotProvider>();
    final connection = context.watch<ConnectionProvider>();
    final query = _search.text.trim().toLowerCase();
    final users = provider.users.where((user) =>
      query.isEmpty ||
      user.name.toLowerCase().contains(query) ||
      user.profile.toLowerCase().contains(query) ||
      user.comment.toLowerCase().contains(query)
    ).toList();
    final enabledCount = provider.users.where((user) => !user.disabled).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الهوتسبوت'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isLoading ? null : provider.fetchUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: connection.isConnected && !provider.isLoading
            ? () => _generateVouchers(provider)
            : null,
        backgroundColor: NovaColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إنشاء بطاقات'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetchUsers,
        color: NovaColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                gradient: NovaColors.gradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NovaColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البطاقات والحسابات',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('إضافة وتعديل وتعطيل وحذف الحسابات مباشرة من MikroTik.',
                      style: TextStyle(color: NovaColors.muted, height: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CountMetric(
                          title: 'إجمالي الحسابات',
                          value: '${provider.users.length}',
                          icon: Icons.badge_outlined,
                          color: NovaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CountMetric(
                          title: 'جلسات نشطة',
                          value: '${provider.activeCount}',
                          icon: Icons.wifi_tethering_rounded,
                          color: NovaColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CountMetric(
                          title: 'حسابات مفعلة',
                          value: '$enabledCount',
                          icon: Icons.check_circle_outline_rounded,
                          color: NovaColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث باسم البطاقة أو البروفايل',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (!connection.isConnected)
              const GlassCard(
                child: _EmptyState(
                  title: 'لا يوجد اتصال بالراوتر',
                  message: 'ارجع إلى شاشة الاتصال وسجّل الدخول إلى جهاز MikroTik.',
                  icon: Icons.link_off_rounded,
                ),
              )
            else if (provider.isLoading && provider.users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.users.isEmpty)
              GlassCard(
                child: _EmptyState(
                  title: 'تعذّر تحميل الحسابات',
                  message: provider.error!,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (users.isEmpty)
              GlassCard(
                child: _EmptyState(
                  title: query.isEmpty ? 'لا توجد بطاقات' : 'لا توجد نتائج',
                  message: query.isEmpty
                      ? 'أنشئ أول مجموعة بطاقات من زر «إنشاء بطاقات».'
                      : 'غيّر كلمة البحث ثم حاول مجدداً.',
                  icon: Icons.credit_card_off_rounded,
                ),
              )
            else
              ...users.map((user) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HotspotUserCard(
                      user: user,
                      onEdit: () => _editUser(user, provider),
                      onDelete: () => _deleteUser(user, provider),
                      onToggle: (value) async {
                        final ok = await provider.toggleUserStatus(user.id, user.disabled);
                        if (!mounted) return;
                        if (!ok) {
                          _message(provider.error ?? 'تعذر تغيير حالة البطاقة.', success: false);
                        }
                      },
                    ),
                  )),
            if (provider.error != null && provider.users.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(provider.error!, style: const TextStyle(color: NovaColors.warn, fontSize: 12)),
            ],
            if (provider.isLoading && provider.users.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _HotspotUserCard extends StatelessWidget {
  final HotspotUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _HotspotUserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !user.disabled;
    final bytes = (double.tryParse(user.bytesOut) ?? 0) / 1048576;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (enabled ? NovaColors.cyan : NovaColors.danger).withOpacity(.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: enabled ? NovaColors.cyan : NovaColors.danger,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'البروفايل: ${user.profile}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NovaColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'رفع مسجل: ${bytes.toStringAsFixed(1)} MB',
                  style: const TextStyle(color: NovaColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Text(
                  enabled ? 'الحساب مفعّل' : 'الحساب معطّل',
                  style: TextStyle(
                    color: enabled ? NovaColors.success : NovaColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل البطاقة',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'حذف البطاقة',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: NovaColors.danger, size: 20),
              ),
            ],
          ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeColor: NovaColors.success,
          ),
        ],
      ),
    );
  }
}

class _CountMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CountMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: NovaColors.surface2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 9),
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  const _EmptyState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 36, color: NovaColors.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: NovaColors.muted, height: 1.5)),
        ],
      );
}