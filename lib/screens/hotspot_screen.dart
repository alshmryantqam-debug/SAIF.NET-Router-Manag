import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';
import '../models/hotspot_user.dart';

class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});
  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ConnectionProvider>().fetchHotspotUsers());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('مستخدمو الهوتسبوت'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryBlue),
            onPressed: () => provider.fetchHotspotUsers(),
          )
        ],
      ),
      body: provider.hotspotUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.hotspotUsers.length,
              itemBuilder: (context, index) {
                final user = provider.hotspotUsers[index];
                return _buildUserTile(user, provider);
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // نافذة منبثقة سريعة لإضافة مستخدم
          showDialog(
            context: context,
            builder: (ctx) {
              final nameCtrl = TextEditingController();
              final passCtrl = TextEditingController();
              return AlertDialog(
                backgroundColor: AppTheme.cardDark,
                title: const Text('إضافة مستخدم هوتسبوت'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
                    TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                  ElevatedButton(
                    onPressed: () {
                      if(nameCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                        provider.addHotspotUser(nameCtrl.text, passCtrl.text, 'default');
                        Navigator.pop(ctx);
                      }
                    }, 
                    child: const Text('حفظ')
                  ),
                ],
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildUserTile(HotspotUser user, ConnectionProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF1E293B),
            child: Icon(Icons.wifi, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('الباقة: ${user.profile}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.dangerRed),
            onPressed: () => provider.deleteHotspotUser(user.id),
          )
        ],
      ),
    );
  }
}