import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/cyber_defense_provider.dart';
import '../widgets/cyber_threat_radar.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class CyberDefenseScreen extends StatefulWidget {
  const CyberDefenseScreen({super.key});

  @override
  State<CyberDefenseScreen> createState() => _CyberDefenseScreenState();
}

class _CyberDefenseScreenState extends State<CyberDefenseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CyberDefenseProvider>().refresh();
    });
  }

  Future<void> _enableShield(CyberDefenseProvider provider) async {
    final target = provider.selectedInterface;
    if (target == null) return;

    final currentArp = _arpLabel(target['arp']?.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('تأكيد إجراء الحماية', style: TextStyle(color: Colors.white)),
        content: Text(
          'سيتم تغيير سياسة جدول العناوين في المنفذ "${target['name']}" من "$currentArp" إلى "الرد فقط". قد ينقطع اتصال أجهزة لا تملك سجلات عناوين صحيحة. تأكد من اكتمال سجلات العناوين الثابتة قبل المتابعة.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5A33D)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد التغيير'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await provider.enableArpReplyOnly();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? provider.notice : provider.error),
      backgroundColor: success ? const Color(0xFF176B55) : const Color(0xFF9D2634),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CyberDefenseProvider>();
    final connected = context.watch<ConnectionProvider>().isConnected;
    final threat = state.hasDhcpAlerts;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'درع الحماية السيبراني',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تحديث من الراوتر',
              onPressed: state.isLoading ? null : state.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(child: CyberThreatRadar(hasThreat: threat)),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    !connected
                        ? 'النظام غير متصل بالراوتر'
                        : state.isLoading
                            ? 'جارٍ فحص سجلات الراوتر'
                            : threat
                                ? 'إنذار: توجد مؤشرات مسجلة تستحق التحقيق'
                                : 'لا توجد مؤشرات مطابقة في السجل المقروء',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !connected
                          ? Colors.orangeAccent
                          : threat
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF27C9FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الرادار مؤثر بصري؛ حالة الإنذار أدناه مبنية على سجلات الراوتر الفعلية. غياب التنبيه لا يثبت خلو الشبكة من خادم دخيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                ),
                const SizedBox(height: 20),
                if (state.error.isNotEmpty) ...[
                  _noticePanel(state.error, const Color(0xFFFF5252), Icons.error_outline),
                  const SizedBox(height: 12),
                ],
                if (state.notice.isNotEmpty) ...[
                  _noticePanel(state.notice, const Color(0xFF27C9FF), Icons.info_outline),
                  const SizedBox(height: 12),
                ],
                NovaTechPanel(
                  accentColor: threat ? const Color(0xFFFF5252) : const Color(0xFF27C9FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.radar_rounded, color: Color(0xFF27C9FF)),
                        SizedBox(width: 10),
                        Expanded(child: Text('مراقبة مؤشرات خادم العناوين الدخيل', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                      ]),
                      const Divider(color: Colors.white24, height: 24),
                      if (state.dhcpAlerts.isEmpty)
                        const Text(
                          'لا توجد حالياً سجلات مقروءة تطابق قواعد التنبيه المحددة. واجهة سجل الراوتر ليست بديلاً عن التقاط عروض DHCP على الشبكة.',
                          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
                        )
                      else
                        ...state.dhcpAlerts.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.5)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(entry['time']?.toString() ?? 'وقت غير مسجل', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 5),
                              Text(entry['message']?.toString() ?? 'سجل بلا تفاصيل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        )),
                      const SizedBox(height: 12),
                      const Text('خوادم العناوين المهيأة على الراوتر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (state.dhcpServers.isEmpty)
                        const Text('لم تُقرأ خوادم مهيأة، أو لم يكتمل الفحص.', style: TextStyle(color: Colors.white54, fontSize: 12))
                      else
                        ...state.dhcpServers.map((server) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Icon(Icons.dns_rounded, color: Color(0xFF27C9FF), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(server['name']?.toString() ?? 'خادم بلا اسم', style: const TextStyle(color: Colors.white))),
                            Text(server['interface']?.toString() ?? 'منفذ غير محدد', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(width: 8),
                            Text(server['disabled']?.toString() == 'true' ? 'متوقف' : 'مهيأ', style: TextStyle(color: server['disabled']?.toString() == 'true' ? Colors.white54 : const Color(0xFF4CAE7D), fontSize: 11)),
                          ]),
                        )),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: state.isLoading ? null : state.refresh,
                          icon: const Icon(Icons.travel_explore_rounded),
                          label: const Text('فحص السجلات من الراوتر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF27C9FF),
                            side: const BorderSide(color: Color(0xFF27C9FF)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NovaTechPanel(
                  accentColor: const Color(0xFF27C9FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.shield_rounded, color: Color(0xFF27C9FF)),
                        SizedBox(width: 10),
                        Expanded(child: Text('درع مقاومة قطع الاتصال', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                      ]),
                      const Divider(color: Colors.white24, height: 24),
                      const Text(
                        'يمكن ضبط سياسة العناوين إلى "الرد فقط" على منفذ مدعوم. هذا الإجراء وحده لا يمنع كل هجمات قطع الاتصال، ويجب التأكد من وجود سجلات عناوين ثابتة قبل تطبيقه.',
                        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: state.selectedInterfaceId,
                        dropdownColor: const Color(0xFF111827),
                        decoration: InputDecoration(
                          labelText: 'المنفذ المستهدف',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: state.supportedInterfaces.map((item) {
                          final type = item['type']?.toString() == 'bridge' ? 'جسر' : 'منفذ شبكي';
                          return DropdownMenuItem<String>(
                            value: item['.id'].toString(),
                            child: Text('${item['name']} — $type'),
                          );
                        }).toList(),
                        onChanged: state.isApplyingArp ? null : state.selectInterface,
                      ),
                      const SizedBox(height: 12),
                      if (state.selectedInterface != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: state.selectedInterfaceIsReplyOnly
                                ? const Color(0xFF4CAE7D).withOpacity(0.12)
                                : Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: state.selectedInterfaceIsReplyOnly
                                  ? const Color(0xFF4CAE7D)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              state.selectedInterfaceIsReplyOnly ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                              color: state.selectedInterfaceIsReplyOnly ? const Color(0xFF4CAE7D) : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              'حالة السياسة الحالية: ${_arpLabel(state.selectedInterface?['arp']?.toString())}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )),
                          ]),
                        )
                      else
                        const Text('لا يوجد منفذ جسر أو منفذ شبكي مدعوم في البيانات المقروءة.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: !connected || state.isLoading || state.isApplyingArp ||
                                  state.selectedInterface == null || state.selectedInterfaceIsReplyOnly
                              ? null
                              : () => _enableShield(state),
                          icon: state.isApplyingArp
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.gpp_good_rounded),
                          label: Text(state.selectedInterfaceIsReplyOnly
                              ? 'الحماية مفعّلة وفق قراءة الراوتر'
                              : 'تفعيل وضع الرد فقط'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF147D83),
                            disabledBackgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _arpLabel(String? mode) {
    switch (mode) {
      case 'enabled':
        return 'مفعّل';
      case 'reply-only':
        return 'الرد على السجلات فقط';
      case 'proxy-arp':
        return 'الرد بالوكالة';
      case 'disabled':
        return 'معطّل';
      default:
        return 'غير معروف';
    }
  }

  Widget _noticePanel(String message, Color color, IconData icon) => NovaTechPanel(
    accentColor: color,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white70, height: 1.5))),
    ]),
  );
}
