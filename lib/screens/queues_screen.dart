import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';

class QueuesScreen extends StatefulWidget {
  const QueuesScreen({super.key});
  @override
  State<QueuesScreen> createState() => _QueuesScreenState();
}

class _QueuesScreenState extends State<QueuesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ConnectionProvider>().fetchQueues());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('الطوابير (Queues)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.queues.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.queues.length,
              itemBuilder: (context, index) {
                final q = provider.queues[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.speed, color: AppTheme.primaryPurple),
                    title: Text(q['name'] ?? 'Queue', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Download: ${q['max-limit'] ?? '--'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                );
              },
            ),
    );
  }
}