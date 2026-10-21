import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pppoe_provider.dart';
import 'active_sessions_screen.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class PppoeScreen extends StatefulWidget {
  const PppoeScreen({super.key});

  @override
  State<PppoeScreen> createState() => _PppoeScreenState();
}

class _PppoeScreenState extends State<PppoeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PppoeProvider>().fetchUsers();
    });
  }

  Future<void> _showAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final profileCtrl = TextEditingController(text: 'default');
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('إضافة مشترك جديد', style: TextStyle(color: AppTheme.textPrimary)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم المستخدم' : null,
                ),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة المرور' : null,
                ),
                TextFormField(
                  controller: profileCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'البروفايل (Profile)'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم البروفايل' : null,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.dangerColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: submitting ? null : () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setDialogState(() => submitting = true);
                final provider = context.read<PppoeProvider>();
                final success = await provider.addUser(nameCtrl.text, passCtrl.text, profileCtrl.text);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'تمت إضافة المشترك بنجاح' : (provider.errorMessage.isNotEmpty ? provider.errorMessage : 'تعذرت إضافة المشترك')),
                  backgroundColor: success ? AppTheme.successColor : AppTheme.dangerColor,
                ));
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    passCtrl.dispose();
    profileCtrl.dispose();
  }

  Future<void> _toggleUser(PppoeProvider provider, String id, bool disabled) async {
    final success = await provider.toggleUserStatus(id, disabled);
    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(provider.errorMessage.isNotEmpty ? provider.errorMessage : 'تعذر تغيير حالة المشترك'),
      backgroundColor: AppTheme.dangerColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PppoeProvider>();
    final users = provider.users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشتركو PPPoE'),
        actions: [
          IconButton(
            tooltip: 'الجلسات النشطة',
            icon: const Icon(Icons.devices_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActiveSessionsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تحديث القائمة',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.fetchUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        tooltip: 'إضافة مشترك',
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.cardColor,
        onRefresh: provider.fetchUsers,
        child: provider.isLoading && users.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              ])
            : users.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: [
                    const SizedBox(height: 70),
                    Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.7)),
                    const SizedBox(height: 16),
                    const Center(child: Text('لا يوجد مشتركون لعرضهم', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16))),
                    if (provider.errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(provider.errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 18),
                    Center(child: OutlinedButton.icon(onPressed: provider.fetchUsers, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
                  ])
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: users.length + (provider.errorMessage.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(provider.errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.dangerColor)));
                      }
                      final user = users[index];
                      final enabled = !user.disabled;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: (enabled ? AppTheme.successColor : AppTheme.dangerColor).withOpacity(0.18),
                              child: Icon(Icons.person_outline, color: enabled ? AppTheme.successColor : AppTheme.dangerColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Text('الباقة: ${user.profile}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(height: 3),
                              Text(enabled ? 'مفعّل' : 'معطّل', style: TextStyle(fontSize: 12, color: enabled ? AppTheme.successColor : AppTheme.dangerColor)),
                            ])),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: enabled,
                              activeColor: AppTheme.successColor,
                              onChanged: provider.isLoading ? null : (_) => _toggleUser(provider, user.id, user.disabled),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
