import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../providers/connection_provider.dart';

class LoadBalancingWizardScreen extends StatefulWidget {
  const LoadBalancingWizardScreen({super.key});

  @override
  State<LoadBalancingWizardScreen> createState() => _LoadBalancingWizardScreenState();
}

class _LoadBalancingWizardScreenState extends State<LoadBalancingWizardScreen> {
  bool wan1 = true, wan2 = true, wan3 = false;
  bool _busy = false;

  // هذا السكربت مثال ثابت وليس مولداً من مفاتيح WAN.
  // لا تنفذه قبل استبدال البوابات ومراجعته مقابل إعدادات PCC الحالية.
  String get script => """
# سكربت دمج تجريبي - نوفا
# عناوين البوابات التالية أمثلة وليست مؤكدة لشبكتك
/ip firewall mangle
add chain=prerouting action=mark-connection new-connection-mark=conn1 passthrough=yes in-interface=ether1
add chain=prerouting action=mark-connection new-connection-mark=conn2 passthrough=yes in-interface=ether2
add chain=prerouting action=mark-routing new-routing-mark=route1 passthrough=no connection-mark=conn1
add chain=prerouting action=mark-routing new-routing-mark=route2 passthrough=no connection-mark=conn2
/ip route
add gateway=192.168.1.2 routing-table=route1 check-gateway=ping
add gateway=192.168.2.2 routing-table=route2 check-gateway=ping
""";

  Future<void> _confirmAndExecute() async {
    if (!wan1 && !wan2 && !wan3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر خط إنترنت واحداً على الأقل.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    bool backupReady = false;
    bool rollbackReady = false;
    bool scriptReviewed = false;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text(
            'تأكيد التنفيذ على الراوتر',
            style: TextStyle(color: AppTheme.dangerRed),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحذير: هذا سكربت تجريبي يضيف قواعد mangle ومسارات جديدة، وقد يتعارض مع PCC الحالي أو يقطع الإنترنت. مفاتيح WAN لا تغيّر محتوى السكربت، والبوابتان 192.168.1.2 و192.168.2.2 أمثلة فقط. لا تتابع إلا بعد تخصيص السكربت لشبكتك.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: backupReady,
                  onChanged: (value) => setDialogState(() => backupReady = value ?? false),
                  title: const Text('أنشأت نسخة احتياطية حديثة ويمكنني استعادتها'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: rollbackReady,
                  onChanged: (value) => setDialogState(() => rollbackReady = value ?? false),
                  title: const Text('لدي اتصال بديل وخطة تراجع'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: scriptReviewed,
                  onChanged: (value) => setDialogState(() => scriptReviewed = value ?? false),
                  title: const Text('راجعت البوابات وقواعد PCC والجداول على الراوتر'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
              onPressed: backupReady && rollbackReady && scriptReviewed
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('تأكيد الإرسال'),
            ),
          ],
        ),
      ),
    );

    if (approved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final success = await context.read<ConnectionProvider>().executeLoadBalancingScript(script);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'أُرسل السكربت للتنفيذ. تحقق من سجل الراوتر والاتصال؛ لا يعني الرد نجاح كل قاعدة.'
                : 'فشل إرسال السكربت. تحقق من صلاحيات REST وسجل الراوتر.',
          ),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التنفيذ: $e'), backgroundColor: AppTheme.dangerRed),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('مهندس دمج الخطوط'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر خطوط الإنترنت (WAN)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                ),
                SwitchListTile(
                  title: const Text('ether1 (Starlink 1)'),
                  value: wan1,
                  onChanged: _busy ? null : (value) => setState(() => wan1 = value),
                  activeColor: AppTheme.primaryPurple,
                ),
                SwitchListTile(
                  title: const Text('ether2 (Starlink 2)'),
                  value: wan2,
                  onChanged: _busy ? null : (value) => setState(() => wan2 = value),
                  activeColor: AppTheme.primaryPurple,
                ),
                SwitchListTile(
                  title: const Text('ether3 (الخط التركي)'),
                  value: wan3,
                  onChanged: _busy ? null : (value) => setState(() => wan3 = value),
                  activeColor: AppTheme.primaryPurple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'السكربت المعروض (مثال ثابت يحتاج تخصيصاً قبل التنفيذ):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(
              script,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.successGreen,
                fontSize: 11,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'مهم: مفاتيح WAN حالياً للعرض فقط ولا تغيّر السكربت. لا تطبّقه على CCR2116 الإنتاجي قبل مواءمته مع RouterOS 7 وإعدادات PCC والبوابات الفعلية.',
            style: TextStyle(color: AppTheme.warningOrange, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _busy ? null : _confirmAndExecute,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text(
                      'تطبيق الدمج (PCC)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}