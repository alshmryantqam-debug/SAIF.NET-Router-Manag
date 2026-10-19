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
  bool wan1 = true, wan2 = true, wan3 = true;

  String get script => """
# سكربت الدمج التلقائي - نوفا
/ip firewall mangle
add chain=prerouting action=mark-connection new-connection-mark=conn1 passthrough=yes in-interface=ether1
add chain=prerouting action=mark-connection new-connection-mark=conn2 passthrough=yes in-interface=ether2
add chain=prerouting action=mark-routing new-routing-mark=route1 passthrough=no connection-mark=conn1
add chain=prerouting action=mark-routing new-routing-mark=route2 passthrough=no connection-mark=conn2
/ip route
add gateway=192.168.1.2 routing-mark=route1 check-gateway=ping
add gateway=192.168.2.2 routing-mark=route2 check-gateway=ping
""";

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
                const Text('اختر خطوط الإنترنت (WAN)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                SwitchListTile(title: const Text('ether1 (Starlink 1)'), value: wan1, onChanged: (v) => setState(() => wan1 = v), activeColor: AppTheme.primaryPurple),
                SwitchListTile(title: const Text('ether2 (Starlink 2)'), value: wan2, onChanged: (v) => setState(() => wan2 = v), activeColor: AppTheme.primaryPurple),
                SwitchListTile(title: const Text('ether3 (الخط التركي)'), value: wan3, onChanged: (v) => setState(() => wan3 = v), activeColor: AppTheme.primaryPurple),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('السكربت المتوقع:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Text(script, style: const TextStyle(fontFamily: 'monospace', color: AppTheme.successGreen, fontSize: 11), textDirection: TextDirection.ltr),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardDark,
                    title: const Text('تأكيد التنفيذ'),
                    content: const Text('سيتم تطبيق سكربت الدمج على الراوتر. هل أنت متأكد؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال السكربت للراوتر')));
                        }, 
                        child: const Text('تنفيذ')
                      ),
                    ],
                  ),
                );
              },
              child: const Text('تطبيق الدمج (PCC)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}