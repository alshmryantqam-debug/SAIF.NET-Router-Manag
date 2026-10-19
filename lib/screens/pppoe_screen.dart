import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';
import '../models/pppoe_user.dart';
import 'add_pppoe_screen.dart';

class PppoeScreen extends StatefulWidget {
  const PppoeScreen({super.key});
  @override
  State<PppoeScreen> createState() => _PppoeScreenState();
}

class _PppoeScreenState extends State<PppoeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ConnectionProvider>().fetchPPPoEUsers());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('مشتركو PPPoE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple),
            onPressed: () => provider.fetchPPPoEUsers(),
          )
        ],
      ),
      body: provider.pppoeUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pppoeUsers.length,
              itemBuilder: (context, index) {
                final user = provider.pppoeUsers[index];
                return _buildUserTile(user, provider);
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPppoeScreen())),
      ),
    );
  }

  Widget _buildUserTile(PPPoEUser user, ConnectionProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: user.disabled ? Colors.red.withOpacity(0.3) : Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.disabled ? AppTheme.dangerRed.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1),
            child: Icon(Icons.person, color: user.disabled ? AppTheme.dangerRed : AppTheme.successGreen),
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
          Switch(
            value: !user.disabled,
            activeColor: AppTheme.successGreen,
            onChanged: (val) {
              provider.togglePPPoEUser(user.id, !val);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.dangerRed),
            onPressed: () {
              provider.deletePPPoEUser(user.id);
            },
          )
        ],
      ),
    );
  }
}