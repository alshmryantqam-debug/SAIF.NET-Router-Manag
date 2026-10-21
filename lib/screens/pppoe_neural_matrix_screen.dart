import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/particle_matrix_bg.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/cyber_neural_painter.dart';

const Color _neuralCyan = Color(0xFF00E5FF);
const Color _neuralPink = Color(0xFFE040FB);
const Color _neuralRed = Color(0xFFFF5252);

class PppoeNeuralMatrixScreen extends StatelessWidget {
  const PppoeNeuralMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080611),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'العودة إلى مشتركي PPPoE',
          onPressed: () => context.go('/pppoe'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: const Text(
          'المصفوفة العصبية',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Colors.white,
            shadows: <Shadow>[
              Shadow(color: _neuralPink, blurRadius: 10),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                height: 320,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _neuralCyan.withOpacity(0.32),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _neuralCyan.withOpacity(0.07),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const CyberNeuralPainter(nodeCount: 35),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _statusChip(
                        'شبكة مرئية تجريبية',
                        _neuralCyan,
                        Icons.hub_rounded,
                      ),
                    ),
                    const Positioned(
                      bottom: 14,
                      right: 14,
                      child: Text(
                        'PPPoE / NEURAL TOPOLOGY',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildStatCard(
                        'جلسات نشطة',
                        '—',
                        _neuralCyan,
                        Icons.hub_rounded,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _buildStatCard(
                        'تنبيهات مؤكدة',
                        '—',
                        _neuralRed,
                        Icons.gpp_bad_rounded,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _buildStatCard(
                        'استقرار الاتصال',
                        '—',
                        _neuralPink,
                        Icons.analytics_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: NovaTechPanel(
                    accentColor: _neuralPink,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(
                              Icons.radar_rounded,
                              color: _neuralPink,
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'محلل جلسات المشتركين',
                                style: TextStyle(
                                  color: _neuralPink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'API غير مربوط',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.account_tree_rounded,
                                    color: Colors.white.withOpacity(0.22),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'المصفوفة جاهزة لاستقبال بيانات Riverpod',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'العُقد والنبضات أعلاه للعرض البصري فقط. '
                                    'لن تُعرض أعداد جلسات أو حالات أمنية قبل '
                                    'ربط مصدر PPPoE الحقيقي.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.56),
                                      fontSize: 11,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: NovaCyberButton(
                            text: 'مزامنة العصبونات الحية',
                            icon: Icons.sync_rounded,
                            color: Colors.grey,
                            onPressed: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
