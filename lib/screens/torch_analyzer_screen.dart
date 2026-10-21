import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/torch_provider.dart';
import '../widgets/particle_matrix_bg.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/cyber_torch_visualizer.dart';

class TorchAnalyzerScreen extends StatefulWidget {
  const TorchAnalyzerScreen({super.key});
  @override
  State<TorchAnalyzerScreen> createState() => _TorchAnalyzerScreenState();
}

class _TorchAnalyzerScreenState extends State<TorchAnalyzerScreen> {
  String? _selectedInterface;

  @override
  Widget build(BuildContext context) {
    final interfaces = context.watch<ConnectionProvider>().interfaces
        .whereType<Map>()
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
          title: const Text('مصيدة الحزم السيبرانية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, shadows: [Shadow(color: Color(0xFFFF5252), blurRadius: 10)])),
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: Consumer<TorchProvider>(builder: (context, provider, _) {
              final selected = interfaces.contains(_selectedInterface) ? _selectedInterface : (interfaces.isNotEmpty ? interfaces.first : null);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF5252).withOpacity(.5))),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: selected, isExpanded: true, dropdownColor: const Color(0xFF0A0E17),
                        hint: const Text('اختر واجهة من الراوتر', style: TextStyle(color: Colors.white54)),
                        icon: const Icon(Icons.settings_ethernet_rounded, color: Color(0xFFFF5252)),
                        items: interfaces.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: provider.isSniffing ? null : (value) => setState(() => _selectedInterface = value),
                      )),
                    )),
                    const SizedBox(width: 10),
                    SizedBox(height: 48, width: 52, child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: provider.isSniffing ? const Color(0xFFFF5252) : const Color(0xFF4CAE7D), padding: EdgeInsets.zero),
                      onPressed: selected == null ? null : () => provider.isSniffing ? provider.stopSniffing() : provider.startSniffing(selected),
                      child: Icon(provider.isSniffing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
                    )),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CyberTorchVisualizer(isSniffing: provider.isSniffing, packets: provider.packets),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(provider.statusMessage, style: TextStyle(color: provider.isSniffing ? const Color(0xFFFF5252) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                    if (provider.errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(provider.errorMessage, style: const TextStyle(color: Color(0xFFFF7070), fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ]),
                ),
                Expanded(child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(.35), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
                  child: provider.packets.isEmpty
                    ? Center(child: Text(provider.isSniffing ? 'بانتظار بيانات الراوتر…' : 'لا توجد بيانات ملتقطة', style: const TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10), itemCount: provider.packets.length,
                        itemBuilder: (context, index) {
                          final packet = provider.packets[index];
                          final accent = packet.protocol == 'UDP' ? const Color(0xFFE040FB) : const Color(0xFF00E5FF);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: NovaTechPanel(
                              accentColor: accent,
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: accent.withOpacity(.12), borderRadius: BorderRadius.circular(8)), child: Text(packet.protocol, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w900))),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('المصدر: ${packet.srcIp}', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                                  const SizedBox(height: 4),
                                  Text('الهدف: ${packet.dstIp}  •  المنفذ: ${packet.port}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                ])),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('إرسال ${packet.txSpeed.toStringAsFixed(2)} ميغابت', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text('استقبال ${packet.rxSpeed.toStringAsFixed(2)} ميغابت', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                )),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
