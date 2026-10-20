import 'package:flutter/material.dart';

import 'interfaces_screen.dart';
import 'load_balancing_wizard_screen.dart';
import 'queues_screen.dart';
import 'terminal_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <_ToolItem>[
      _ToolItem(
        title: 'واجهات الشبكة',
        subtitle: 'مراقبة منافذ الراوتر وحالتها',
        icon: Icons.cable_outlined,
        builder: (_) => const InterfacesScreen(),
      ),
      _ToolItem(
        title: 'موازنة الأحمال',
        subtitle: 'إعداد ومراجعة خطوط الإنترنت',
        icon: Icons.account_tree_outlined,
        builder: (_) => const LoadBalancingWizardScreen(),
      ),
      _ToolItem(
        title: 'إدارة الطوابير',
        subtitle: 'مراجعة حدود السرعة',
        icon: Icons.speed_outlined,
        builder: (_) => const QueuesScreen(),
      ),
      _ToolItem(
        title: 'طرفية الراوتر',
        subtitle: 'تنفيذ أوامر RouterOS',
        icon: Icons.terminal_outlined,
        builder: (_) => const TerminalScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('الأدوات')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return Card(
            child: ListTile(
              leading: Icon(tool.icon),
              title: Text(tool.title),
              subtitle: Text(tool.subtitle),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: tool.builder),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}
