import 'package:flutter/material.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal')),
      body: const Center(
        child: Text('الطرفية معطّلة لحماية الراوتر.'),
      ),
    );
  }
}
