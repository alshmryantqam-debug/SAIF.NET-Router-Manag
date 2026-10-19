import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';

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
              },
            ),
    );
  }
}