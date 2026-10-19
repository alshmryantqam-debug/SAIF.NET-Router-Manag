import 'package:flutter/material.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final List<String> _logs = [
    '[SYSTEM] Nova OS v1.0 Initialized...',
    '[SYSTEM] Connecting to RouterOS...',
    '[SUCCESS] Connection established.',
    '[INFO] Type commands here (e.g., /ip address print)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('RouterOS Terminal', style: TextStyle(fontFamily: 'monospace', color: AppTheme.successGreen)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.successGreen),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13),
                    textDirection: TextDirection.ltr,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF111111), border: Border(top: BorderSide(color: Colors.white12))),
            child: Row(
              children: [
                const Text('> ', style: TextStyle(color: AppTheme.successGreen, fontFamily: 'monospace', fontSize: 18)),
                const Expanded(
                  child: TextField(
                    style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'أدخل أمر RouterOS...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryPurple),
                  onPressed: () {},
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}