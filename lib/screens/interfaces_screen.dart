import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';

class InterfacesScreen extends StatefulWidget {
  const InterfacesScreen({super.key});
  @override
  State<InterfacesScreen> createState() => _InterfacesScreenState();
}

class _InterfacesScreenState extends State<InterfacesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ConnectionProvider>().fetchInterfaces());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('المنافذ (Interfaces)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.interfaces.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.interfaces.length,
              itemBuilder: (context, index) {
                final intf = provider.interfaces[index];
                bool isRunning = intf['running'] == 'true';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.settings_ethernet, color: isRunning ? AppTheme.successGreen : AppTheme.dangerRed),
                    title: Text(intf['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('TX: ${intf['tx-byte'] ?? 0} | RX: ${intf['rx-byte'] ?? 0}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    trailing: Text(isRunning ? 'يعمل' : 'متوقف', style: TextStyle(color: isRunning ? AppTheme.successGreen : AppTheme.dangerRed, fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}