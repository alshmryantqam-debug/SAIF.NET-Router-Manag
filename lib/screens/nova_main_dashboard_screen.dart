import 'package:flutter/material.dart';
import '../widgets/particle_matrix_bg.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/cyber_module_card.dart';

class NovaMainDashboardScreen extends StatefulWidget {
  const NovaMainDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NovaMainDashboardScreen> createState() => _NovaMainDashboardScreenState();
}

class _NovaMainDashboardScreenState extends State<NovaMainDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showModuleNotice(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('وحدة $title جاهزة للربط بالخدمة الفعلية'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF182337),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const magenta = Color(0xFFE040FB);
    const green = Color(0xFF4CAE7D);
    const red = Color(0xFFFF5252);
    const gold = Color(0xFFE5C158);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'مركز القيادة — نوفا',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
              shadows: [Shadow(color: cyan, blurRadius: 10)],
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'حالة الاتصال',
            icon: const Icon(Icons.cloud_sync_rounded, color: green),
            onPressed: () => _showModuleNotice('الاتصال الآمن'),
          ),
        ),
        body: ParticleMatrixBg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              physics: const BouncingScrollPhysics(),
              children: [
                NovaTechPanel(
                  accentColor: cyan,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildVitalItem('المعالج', '٣٪', cyan)),
                          Expanded(child: _buildVitalItem('الحرارة', '٤٧°', red)),
                          Expanded(child: _buildVitalItem('الفولت', 'مستقر', green)),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سرعة نقل البيانات',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded, color: cyan, size: 16),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  '١٨٫٧ ميغابت/ث',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.arrow_upward_rounded, color: magenta, size: 16),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  '١٨٣٫٩ كيلوبت/ث',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        children: [
                          const Icon(Icons.storage_rounded, color: Colors.white54, size: 17),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('التخزين: ٩٠ من ١٢٨ ميغابايت', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ),
                          SizedBox(
                            width: 78,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: const LinearProgressIndicator(
                                value: 0.7,
                                minHeight: 5,
                                backgroundColor: Colors.white10,
                                color: cyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'مدة التشغيل: يومان و٥ ساعات',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'قيم توضيحية — تُستبدل بقراءات الراوتر الحية عند ربط الخدمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = _pulseController.value;
                      return Container(
                        width: 138,
                        height: 138,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.42),
                          border: Border.all(
                            color: cyan.withOpacity(0.42 + pulse * 0.55),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cyan.withOpacity(0.12 + pulse * 0.18),
                              blurRadius: 25 + pulse * 14,
                              spreadRadius: 4 + pulse * 5,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _showModuleNotice('الفحص الشامل'),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.radar_rounded, color: cyan, size: 42),
                                SizedBox(height: 8),
                                Text(
                                  'فحص شامل',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 3),
                                Text('محرك الشذوذ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'وحدات القيادة',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.14,
                  children: [
                    CyberModuleCard(title: 'مشتركو النطاق العريض', count: '١٩٥ / ٢٧٤', icon: Icons.router_rounded, color: cyan, onTap: () => _showModuleNotice('النطاق العريض')),
                    CyberModuleCard(title: 'شبكة نقاط الاتصال', count: '١٩٦٤', icon: Icons.cell_wifi_rounded, color: magenta, onTap: () => _showModuleNotice('نقاط الاتصال')),
                    CyberModuleCard(title: 'المتصلون الآن', count: '٣٠', icon: Icons.sensors_rounded, color: green, onTap: () => _showModuleNotice('المتصلون الآن')),
                    CyberModuleCard(title: 'إدارة المستخدمين', icon: Icons.admin_panel_settings_rounded, color: gold, onTap: () => _showModuleNotice('إدارة المستخدمين')),
                    CyberModuleCard(title: 'المبيعات والإيرادات', icon: Icons.account_balance_wallet_rounded, color: green, onTap: () => _showModuleNotice('المبيعات والإيرادات')),
                    CyberModuleCard(title: 'قطاعات البث', count: '٢٦٣', icon: Icons.cell_tower_rounded, color: red, onTap: () => _showModuleNotice('قطاعات البث')),
                    CyberModuleCard(title: 'النسخ الاحتياطي', icon: Icons.data_saver_on_rounded, color: cyan, onTap: () => _showModuleNotice('النسخ الاحتياطي')),
                    CyberModuleCard(title: 'مراسلات واتساب', icon: Icons.chat_rounded, color: green, onTap: () => _showModuleNotice('مراسلات واتساب')),
                    CyberModuleCard(title: 'التنبيهات', icon: Icons.notifications_active_rounded, color: magenta, onTap: () => _showModuleNotice('التنبيهات')),
                    CyberModuleCard(title: 'واجهات ومنافذ الشبكة', icon: Icons.settings_ethernet_rounded, color: Colors.white70, onTap: () => _showModuleNotice('واجهات ومنافذ الشبكة')),
                  ],
                ),
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: magenta, size: 30),
                      const SizedBox(height: 8),
                      const Text(
                        'نواة نوفا — واجهة القيادة',
                        style: TextStyle(color: magenta, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'حالة الاتصال الفعلية تظهر بعد ربط الراوتر',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
