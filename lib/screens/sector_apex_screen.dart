import 'package:flutter/material.dart';

import '../core/theme/nova_theme.dart';
import '../widgets/cyber_sector_radar.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';

/// تعرض القيم غير المتصلة بمصدر قياس حقيقي على هيئة "--".
class SectorApexScreen extends StatefulWidget {
  const SectorApexScreen({super.key});

  @override
  State<SectorApexScreen> createState() => _SectorApexScreenState();
}

class _SectorApexScreenState extends State<SectorApexScreen> {
  bool _isScanning = false;

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _green = Color(0xFF4CAE7D);
  static const Color _amber = Color(0xFFE5C158);

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: NovaColors.bg,
          appBar: AppBar(
            title: const Text(
              'رادار الأبراج والقطاعات',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF111A2C), Color(0xFF0B0F19)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  CyberSectorRadar(isScanning: _isScanning),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning
                        ? 'المسح المرئي نشط — بانتظار ربط مصدر القياس'
                        : 'المراقبة الصامتة · لا توجد قراءة ميدانية بعد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isScanning ? _cyan : NovaColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _metric('الأبراج المسجلة', '--', _cyan, Icons.cell_tower_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _metric('مستوى التشويش', '--', _amber, Icons.waves_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _metric('المشتركون', '--', const Color(0xFFE040FB), Icons.groups_rounded)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle('صحة قطاعات البث'),
                            const Divider(color: Colors.white12, height: 12),
                            Expanded(
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                children: const [
                                  _SectorRow(name: 'البرج الرئيسي · القطاع الشمالي', color: _green),
                                  SizedBox(height: 9),
                                  _SectorRow(name: 'برج البلدية · القطاع الشرقي', color: _amber),
                                  SizedBox(height: 9),
                                  _SectorRow(name: 'برج السوق · القطاع الغربي', color: _green),
                                  SizedBox(height: 9),
                                  _SectorRow(name: 'برج الامتداد · القطاع الجنوبي', color: _cyan),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'البيانات غير مقاسة حتى تفعيل الاتصال الفعلي',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NovaColors.muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => setState(() => _isScanning = !_isScanning),
                        icon: Icon(_isScanning ? Icons.stop_rounded : Icons.radar_rounded),
                        label: Text(_isScanning ? 'إيقاف حركة المسح' : 'بدء المسح المرئي'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isScanning ? const Color(0xFFFF5252) : _cyan.withOpacity(0.16),
                          foregroundColor: _isScanning ? Colors.white : _cyan,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: _isScanning ? const Color(0xFFFF5252) : _cyan.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _metric(String title, String value, Color color, IconData icon) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 7),
            Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SectorRow extends StatelessWidget {
  final String name;
  final Color color;

  const _SectorRow({required this.name, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            const Text('--', style: TextStyle(color: NovaColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
