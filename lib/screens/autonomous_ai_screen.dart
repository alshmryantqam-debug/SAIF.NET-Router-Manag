import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/oracle_provider.dart';
import '../widgets/cyber_oracle_brain.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

class AutonomousAiScreen extends StatelessWidget {
  const AutonomousAiScreen({super.key});

  static const Color cyan = Color(0xFF00E5FF);
  static const Color red = Color(0xFFFF4058);
  static const Color green = Color(0xFF43F5A5);
  static const Color amber = Color(0xFFE5C158);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'أوراكل | العقل المستقل',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
              shadows: [Shadow(color: cyan, blurRadius: 10)],
            ),
          ),
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: Consumer<OracleProvider>(
              builder: (context, provider, _) {
                final hasCritical = provider.anomalies.any(
                  (item) => !item.isResolved && item.severity == OracleSeverity.critical,
                );
                final hasResolved = provider.anomalies.any((item) => item.isResolved);

                return Column(
                  children: [
                    CyberOracleBrain(
                      isScanning: provider.isScanning || provider.isHealing,
                      hasCritical: hasCritical,
                      hasResolved: hasResolved && !hasCritical,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: NovaTechPanel(
                        accentColor: hasCritical ? red : cyan,
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            Icon(
                              provider.isScanning || provider.isHealing
                                  ? Icons.memory_rounded
                                  : Icons.psychology_alt_rounded,
                              color: amber,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                provider.oracleStatus,
                                style: const TextStyle(
                                  color: amber,
                                  fontSize: 12,
                                  height: 1.45,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF092A38),
                            foregroundColor: cyan,
                            side: const BorderSide(color: cyan, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: provider.isScanning || provider.isHealing
                              ? null
                              : provider.initiateDeepScan,
                          icon: const Icon(Icons.radar_rounded),
                          label: Text(
                            provider.isScanning
                                ? 'جارٍ تحليل بيانات الراوتر...'
                                : 'إطلاق المسح العميق',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          _metric('المؤشرات', '${provider.anomalies.length}', cyan),
                          const SizedBox(width: 8),
                          _metric(
                            'حرجة',
                            '${provider.anomalies.where((a) => a.severity == OracleSeverity.critical && !a.isResolved).length}',
                            red,
                          ),
                          const SizedBox(width: 8),
                          _metric(
                            'تم التحقق',
                            '${provider.anomalies.where((a) => a.isResolved).length}',
                            green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: provider.anomalies.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  provider.hasScanned
                                      ? 'لم تُكتشف مؤشرات من مصادر الفحص الحالية. النتيجة لا تضمن خلو الشبكة من الأعطال.'
                                      : 'النواة جاهزة. ابدأ المسح لجمع أدلة فعلية من سجلات RouterOS وواجهاته.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    height: 1.7,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: provider.anomalies.length,
                              itemBuilder: (context, index) {
                                final anomaly = provider.anomalies[index];
                                final resolved = anomaly.isResolved;
                                final critical = anomaly.severity == OracleSeverity.critical;
                                final color = resolved ? green : critical ? red : amber;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 13),
                                  child: NovaTechPanel(
                                    accentColor: color,
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              resolved
                                                  ? Icons.verified_rounded
                                                  : critical
                                                      ? Icons.warning_amber_rounded
                                                      : Icons.radar_rounded,
                                              color: color,
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                anomaly.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              resolved ? 'تم التحقق' : critical ? 'حرج' : 'تحذير',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          anomaly.description,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            height: 1.6,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'الدليل المرصود',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.35),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: SelectableText(
                                            anomaly.evidence,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'الإجراء المقترح: ${anomaly.suggestedAction}',
                                          style: const TextStyle(
                                            color: cyan,
                                            fontSize: 11,
                                            height: 1.6,
                                          ),
                                        ),
                                        const SizedBox(height: 13),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: resolved ? green : color,
                                              side: BorderSide(color: color.withOpacity(0.7)),
                                            ),
                                            onPressed: resolved || provider.isHealing || provider.isScanning
                                                ? null
                                                : () => _confirmRevalidation(context, provider, anomaly.id, anomaly.title),
                                            icon: Icon(resolved ? Icons.check_circle : Icons.healing_rounded),
                                            label: Text(
                                              resolved
                                                  ? 'تم التحقق من زوال المؤشر'
                                                  : provider.isHealing
                                                      ? 'جارٍ التحقق من الحالة...'
                                                      : 'تفويض أوراكل للتحقق والمعالجة الآمنة',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.38)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmRevalidation(
    BuildContext context,
    OracleProvider provider,
    String anomalyId,
    String title,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151426),
        title: const Text('تفويض أوراكل', style: TextStyle(color: Colors.white)),
        content: Text(
          'سيعيد أوراكل فحص «$title» من بيانات الراوتر الحالية. لن يعطّل واجهة أو يفصل مشتركاً تلقائياً.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ابدأ التحقق'),
          ),
        ],
      ),
    );
    if (accepted == true) await provider.executeAutoHeal(anomalyId);
  }
}
