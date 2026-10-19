import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/connection_provider.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final List<String> _logs = [
    '[SYSTEM] Nova OS v1.0 Initialized...',
    '[SYSTEM] RouterOS REST terminal ready.',
    '[INFO] Commands can change the live router. Review and confirm each command.',
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _executeCommand() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty || _isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('تأكيد تنفيذ الأمر'),
        content: SelectableText(
          'سيُرسل الأمر التالي إلى الراوتر المتصل، وقد يغيّر إعداداته أو يقطع الاتصال:\n\n$cmd',
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تأكيد التنفيذ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _logs.add('> $cmd');
      _isLoading = true;
      _controller.clear();
    });

    try {
      final result = await context.read<ConnectionProvider>().executeCommand(cmd);
      if (!mounted) return;
      setState(() => _logs.add(result));
    } catch (e) {
      if (!mounted) return;
      setState(() => _logs.add('ERROR: $e'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

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
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isError = log.startsWith('ERROR:');
                final isCommand = log.startsWith('>');
                final isSuccess = log.startsWith('SUCCESS:');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isError ? Colors.redAccent : (isCommand ? Colors.amberAccent : (isSuccess ? Colors.greenAccent : Colors.white70)),
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: AppTheme.successGreen),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF111111), border: Border(top: BorderSide(color: Colors.white12))),
            child: Row(
              children: [
                const Text('> ', style: TextStyle(color: AppTheme.successGreen, fontFamily: 'monospace', fontSize: 18)),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'أدخل أمر RouterOS...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _executeCommand(),
                  ),
                ),
                IconButton(
                  tooltip: 'تنفيذ الأمر',
                  icon: Icon(_isLoading ? Icons.hourglass_top : Icons.send, color: AppTheme.primaryPurple),
                  onPressed: _isLoading ? null : _executeCommand,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}