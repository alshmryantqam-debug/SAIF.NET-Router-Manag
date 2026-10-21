import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/stealth_shield_provider.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class StarlinkStealthScreen extends StatefulWidget {
  const StarlinkStealthScreen({super.key});

  @override
  State<StarlinkStealthScreen> createState() => _StarlinkStealthScreenState();
}

class _StarlinkStealthScreenState extends State<StarlinkStealthScreen> {
  final TextEditingController _interfaceController = TextEditingController(text: 'ether1');
  final TextEditingController _macController = TextEditingController();

  @override
  void dispose() {
    _interfaceController.dispose();
    _macController.dispose();
    super.dispose();
  }

  Future<void> _run(StealthShieldProvider provider) async {
    final active = provider.isShieldActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(active ? 'تأكيد الاستعادة' : 'تأكيد تعديل منفذ WAN',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          active
              ? 'سيحذف التطبيق قواعد Mangle التي تحمل علامته ثم سيحاول استعادة MAC الأصلي الذي قرأه قبل التغيير. لا تغيّر المنفذ المحدد.'
              : 'سيغيّر التطبيق MAC لمنفذ Ethernet ويضيف قاعدة Mangle تضبط TTL إلى 65. قد ينقطع الاتصال إذا كنت تدير الراوتر عبر هذا المنفذ. استخدم هذه الوظيفة فقط على راوتر تملكه أو تديره وبما تسمح به شروط مزود الخدمة.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (active) {
      await provider.disableCloakingProtocol(_interfaceController.text.trim());
    } else {
      await provider.executeCloakingProtocol(_interfaceController.text.trim(), _macController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StealthShieldProvider>();
    final connected = context.watch<ConnectionProvider>().isConnected;
    const cyan = Color(0xFF00E5FF);
    const red = Color(0xFFFF5252);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('درع اتصال WAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          centerTitle: true,
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.32),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: provider.isShieldActive ? cyan.withOpacity(.65) : Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.satellite_alt_rounded, size: 54, color: provider.isShieldActive ? cyan : Colors.white54),
                      const SizedBox(height: 10),
                      Icon(provider.isShieldActive ? Icons.verified_user_rounded : Icons.router_rounded,
                          size: 32, color: provider.isShieldActive ? cyan : Colors.white70),
                      const SizedBox(height: 8),
                      Text(provider.isShieldActive ? 'CONFIGURATION VERIFIED' : 'WAN CONFIGURATION',
                          style: TextStyle(color: provider.isShieldActive ? cyan : Colors.white70,
                              fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                NovaTechPanel(
                  accentColor: provider.isShieldActive ? cyan : const Color(0xFF9B7CFF),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.terminal_rounded, color: provider.isShieldActive ? cyan : const Color(0xFF4CAE7D)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(provider.terminalLog,
                          style: const TextStyle(color: Color(0xFFB5F7D5), fontSize: 12, height: 1.55))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NovaTechPanel(
                  accentColor: cyan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إعدادات منفذ WAN', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('التغيير حقيقي عبر RouterOS REST. لا توجد محاكاة؛ يعرض السجل نتيجة التحقق من الراوتر.',
                          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.5)),
                      const SizedBox(height: 14),
                      _field(controller: _interfaceController, label: 'اسم منفذ Ethernet', icon: Icons.settings_ethernet_rounded,
                          enabled: !provider.isShieldActive && !provider.isCloaking),
                      const SizedBox(height: 12),
                      _field(controller: _macController, label: 'MAC جديد (مثال: 02:11:22:33:44:55)', icon: Icons.fingerprint_rounded,
                          enabled: !provider.isShieldActive && !provider.isCloaking),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5C158).withOpacity(.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5C158).withOpacity(.35)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFE5C158)),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'تنبيه: تغيير MAC قد يقطع خط WAN أو جلسة الإدارة. استخدم هذه الميزة على راوتر تملكه أو تديره. ضبط TTL لا يضمن إخفاء الراوتر أو تجاوز قيود مزود الخدمة.',
                            style: TextStyle(color: Color(0xFFE5C158), fontSize: 11, height: 1.5))),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: !connected || provider.isCloaking ? null : () => _run(provider),
                          style: FilledButton.styleFrom(
                            backgroundColor: provider.isShieldActive ? red : cyan,
                            foregroundColor: provider.isShieldActive ? Colors.white : const Color(0xFF06121A),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          icon: provider.isCloaking
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(provider.isShieldActive ? Icons.restore_rounded : Icons.security_rounded),
                          label: Text(
                            provider.isCloaking ? 'جارٍ التنفيذ والتحقق...' :
                                provider.isShieldActive ? 'إزالة القاعدة واستعادة MAC' : 'تطبيق إعداد WAN',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      if (!connected) ...[
                        const SizedBox(height: 10),
                        const Text('اتصل بالراوتر من شاشة الدخول أولاً.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        filled: true,
        fillColor: Colors.black.withOpacity(.24),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }
}
