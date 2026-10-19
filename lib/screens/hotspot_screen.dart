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
    Future.microtask(
        () => context.read<ConnectionProvider>().fetchHotspotUsers());
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
            tooltip: 'إعادة تحميل المستخدمين',
            onPressed: provider.isLoading
                ? null
                : () => provider.fetchHotspotUsers(),
          )
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 48, color: AppTheme.dangerRed),
                        const SizedBox(height: 12),
                        Text(
                          provider.errorMessage,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppTheme.dangerRed),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.fetchHotspotUsers(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : provider.hotspotUsers.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمو هوتسبوت لعرضهم.'))
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
                                child: Icon(Icons.wifi,
                                    color: AppTheme.primaryBlue),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text('الباقة: ${user.profile}',
                                        style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: AppTheme.dangerRed),
                                onPressed: () =>
                                    provider.deleteHotspotUser(user.id),
                              )
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
