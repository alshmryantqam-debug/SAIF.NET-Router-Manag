import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotspot_provider.dart';
import 'active_sessions_screen.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class HotspotScreen extends StatefulWidget {
  const HotspotScreen({Key? key}) : super(key: key);

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HotspotProvider>().fetchUsers();
      }
    });
  }

  void _showGenerateDialog() {
    final countCtrl = TextEditingController(text: '10');
    final profileCtrl = TextEditingController(text: 'default');
    final lengthCtrl = TextEditingController(text: '6');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('توليد بطاقات هوتسبوت',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'عدد البطاقات (1–500)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: lengthCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'طول الكود (4–16 رقمًا)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: profileCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'البروفايل (Profile)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.dangerColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final count = int.tryParse(countCtrl.text);
              final length = int.tryParse(lengthCtrl.text);
              final profile = profileCtrl.text.trim();
              if (count == null || count < 1 || count > 500 ||
                  length == null || length < 4 || length > 16 ||
                  profile.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تحقق من العدد وطول الكود واسم البروفايل'),
                  ),
                );
                return;
              }

              final provider = context.read<HotspotProvider>();
              Navigator.pop(dialogContext);
              final success = await provider.generateVouchers(
                count, profile, length.toString());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? 'تم توليد $count بطاقة بنجاح'
                    : 'تعذر توليد البطاقات. تحقق من الاتصال والبروفايل.'),
                backgroundColor: success
                    ? AppTheme.successColor
                    : AppTheme.dangerColor,
              ));
            },
            child: const Text('توليد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).whenComplete(() {
      countCtrl.dispose();
      profileCtrl.dispose();
      lengthCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotspotProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('بطاقات الهوتسبوت'),
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
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.fetchUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.generating_tokens, color: Colors.white),
        label: const Text('توليد بطاقات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: provider.isLoading && provider.users.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardColor,
              onRefresh: provider.fetchUsers,
              child: provider.users.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 100),
                        Icon(Icons.wifi_off, size: 52,
                            color: AppTheme.textSecondary),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'لا توجد بطاقات لعرضها، اسحب للأسفل للتحديث',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.users.length,
                      itemBuilder: (context, index) {
                        final user = provider.users[index];
                        final mbOut =
                            (double.tryParse(user.bytesOut) ?? 0) / 1048576;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: user.disabled
                                      ? AppTheme.dangerColor.withOpacity(0.2)
                                      : AppTheme.warningColor.withOpacity(0.2),
                                  child: Icon(Icons.wifi,
                                      color: user.disabled
                                          ? AppTheme.dangerColor
                                          : AppTheme.warningColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            letterSpacing: 1.5,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${user.profile} | الاستهلاك: ${mbOut.toStringAsFixed(1)} MB',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                      if (user.comment.isNotEmpty)
                                        Text(user.comment,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: !user.disabled,
                                  activeColor: AppTheme.successColor,
                                  inactiveThumbColor: AppTheme.dangerColor,
                                  onChanged: (_) async {
                                    final ok = await provider.toggleUserStatus(
                                        user.id, user.disabled);
                                    if (!context.mounted) return;
                                    if (!ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تعذر تغيير حالة البطاقة'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
