import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/particle_matrix_bg.dart';
import '../widgets/cyber_tool_card.dart';

const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF4081);
const Color _green = Color(0xFF4CAE7D);
const Color _gold = Color(0xFFE5C158);
const Color _purple = Color(0xFF9C27B0);
const Color _red = Color(0xFFFF5252);

class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NOVA | لوحة التحكم',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: <Shadow>[
              Shadow(color: _cyan, blurRadius: 10),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: ParticleMatrixBg(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: 100)),

            _buildSectionHeader(
              'NOVA NETWORK ENGINES',
              Icons.speed_rounded,
              _cyan,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: <Widget>[
                  CyberToolCard(
                    title: 'دمج الخطوط',
                    subtitle: 'PCC Load Balancing',
                    icon: Icons.call_split_rounded,
                    accentColor: _cyan,
                    onTap: () => context.go('/network-engineering'),
                  ),
                  CyberToolCard(
                    title: 'نواة نـوڨـا',
                    subtitle: 'Cake QoS & Netcut Guard',
                    icon: Icons.memory_rounded,
                    accentColor: _pink,
                    onTap: () => context.go('/nova-core-engine'),
                  ),
                ],
              ),
            ),

            _buildSectionHeader(
              'NOVA CLOUD & SECURITY',
              Icons.cloud_done_outlined,
              _green,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: <Widget>[
                  CyberToolCard(
                    title: 'CloudLink',
                    subtitle: 'ربط سحابي عبر WireGuard',
                    icon: Icons.vpn_lock_rounded,
                    accentColor: _green,
                    onTap: () => _showUnavailableFeature(
                      context,
                      title: 'CloudLink / WireGuard',
                      message:
                          'لم تُضَف شاشة إعداد نفق WireGuard إلى هذا الفرع بعد. لم يتم إنشاء نفق أو تغيير أي إعداد في الراوتر.',
                      color: _green,
                    ),
                  ),
                  CyberToolCard(
                    title: 'جدار الحماية',
                    subtitle: 'فلترة المنافذ والهجمات',
                    icon: Icons.security_rounded,
                    accentColor: _gold,
                    onTap: () => context.go('/firewall'),
                  ),
                ],
              ),
            ),

            _buildSectionHeader(
              'NOVA SYSTEM MAINTENANCE',
              Icons.build_circle_outlined,
              _purple,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: <Widget>[
                  CyberToolCard(
                    title: 'نسخ احتياطي',
                    subtitle: 'تشفير وإرسال لتيليجرام',
                    icon: Icons.backup_rounded,
                    accentColor: _purple,
                    onTap: () => context.go('/quantum-backup'),
                  ),
                  CyberToolCard(
                    title: 'إعادة التشغيل',
                    subtitle: 'Reboot RouterBoard',
                    icon: Icons.power_settings_new_rounded,
                    accentColor: _red,
                    onTap: () => _showUnavailableFeature(
                      context,
                      title: 'إعادة تشغيل الراوتر',
                      message:
                          'إجراء إعادة التشغيل غير مربوط حاليًا بالراوتر. لم يُرسل أي أمر إعادة تشغيل.',
                      color: _red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 1,
                color: color.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showUnavailableFeature(
    BuildContext context, {
    required String title,
    required String message,
    required Color color,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF11101D),
        icon: Icon(Icons.info_outline_rounded, color: color, size: 30),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFC4BDD7),
            height: 1.5,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('حسنًا', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
