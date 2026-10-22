import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/cyber_tool_card.dart';
import '../widgets/particle_matrix_bg.dart';

const Color _cyan = Color(0xFF00E5FF);
const Color _violet = Color(0xFFB18CFF);
const Color _pink = Color(0xFFFF5EA8);
const Color _green = Color(0xFF67F5BE);
const Color _amber = Color(0xFFFFC857);

class _ToolEntry {
  const _ToolEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String route;
}

class _ToolCategory {
  const _ToolCategory({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.tools,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<_ToolEntry> tools;
}

const List<_ToolCategory> _toolCategories = <_ToolCategory>[
  _ToolCategory(
    title: 'المشتركون والخدمات',
    description: 'الجلسات، الاشتراكات، وكروت الوصول',
    icon: Icons.people_alt_rounded,
    accent: _violet,
    tools: <_ToolEntry>[
      _ToolEntry(
        title: 'مشتركو PPPoE',
        subtitle: 'ملفات الاشتراك والجلسات',
        icon: Icons.cable_rounded,
        accent: _violet,
        route: '/pppoe',
      ),
      _ToolEntry(
        title: 'المصفوفة العصبية PPPoE',
        subtitle: 'تصوير بصري حي للعُقد والنبضات',
        icon: Icons.hub_rounded,
        accent: _cyan,
        route: '/pppoe/neural-matrix',
      ),
      _ToolEntry(
        title: 'Hotspot',
        subtitle: 'المستخدمون والجلسات النشطة',
        icon: Icons.wifi_rounded,
        accent: _cyan,
        route: '/hotspot',
      ),
      _ToolEntry(
        title: 'كروت الإنترنت',
        subtitle: 'القسائم وإدارة التوزيع',
        icon: Icons.confirmation_number_rounded,
        accent: _amber,
        route: '/voucher',
      ),
    ],
  ),
  _ToolCategory(
    title: 'مراقبة الشبكة',
    description: 'حالة الأجهزة، المنافذ، واكتشاف الربط',
    icon: Icons.radar_rounded,
    accent: _cyan,
    tools: <_ToolEntry>[
      _ToolEntry(
        title: 'لوحة القيادة',
        subtitle: 'مؤشرات الراوتر وحالة النظام',
        icon: Icons.dashboard_rounded,
        accent: _cyan,
        route: '/dashboard',
      ),
      _ToolEntry(
        title: 'أجهزة الراوتر',
        subtitle: 'إدارة ملفات وأجهزة الاتصال',
        icon: Icons.router_rounded,
        accent: _violet,
        route: '/routers',
      ),
      _ToolEntry(
        title: 'واجهات الشبكة',
        subtitle: 'المنافذ وحركة المرور',
        icon: Icons.lan_rounded,
        accent: _green,
        route: '/interfaces',
      ),
      _ToolEntry(
        title: 'مراقبة حركة المرور الحية',
        subtitle: 'متابعة RX وTX مباشرة',
        icon: Icons.show_chart_rounded,
        accent: _cyan,
        route: '/live-traffic',
      ),
      _ToolEntry(
        title: 'رادار أجهزة البث',
        subtitle: 'اكتشاف روابط وأجهزة الراديو',
        icon: Icons.radar_rounded,
        accent: _pink,
        route: '/radio-radar',
      ),
    ],
  ),
  _ToolCategory(
    title: 'الحماية والتشخيص',
    description: 'أدوات التحكم، الفحص، وهندسة الشبكة',
    icon: Icons.shield_rounded,
    accent: _pink,
    tools: <_ToolEntry>[
      _ToolEntry(
        title: 'الجدار الناري',
        subtitle: 'قواعد الحماية والتحكم',
        icon: Icons.security_rounded,
        accent: _pink,
        route: '/firewall',
      ),
      _ToolEntry(
        title: 'Terminal',
        subtitle: 'أوامر RouterOS المباشرة',
        icon: Icons.terminal_rounded,
        accent: _amber,
        route: '/terminal',
      ),
      _ToolEntry(
        title: 'هندسة الشبكة',
        subtitle: 'أدوات التشخيص والتخطيط',
        icon: Icons.hub_rounded,
        accent: _cyan,
        route: '/network-engineering',
      ),
      _ToolEntry(
        title: 'السونار التكتيكي',
        subtitle: 'تصويب الهدف وفحص الاتصال',
        icon: Icons.radar_rounded,
        accent: _cyan,
        route: '/tactical-sonar',
      ),
      _ToolEntry(
        title: 'مفاعل دمج الخطوط (PCC)',
        subtitle: 'توزيع WAN بالأوزان وتطبيق محكوم',
        icon: Icons.merge_type_rounded,
        accent: _cyan,
        route: '/load-balancing-wizard',
      ),
    ],
  ),
  _ToolCategory(
    title: 'الذكاء والأتمتة',
    description: 'التحليل الذكي والعمليات المجدولة',
    icon: Icons.auto_awesome_rounded,
    accent: _green,
    tools: <_ToolEntry>[
      _ToolEntry(
        title: 'الذكاء الاصطناعي',
        subtitle: 'المساعد والتحليل المتقدم',
        icon: Icons.psychology_alt_rounded,
        accent: _violet,
        route: '/advanced-ai',
      ),
      _ToolEntry(
        title: 'الأتمتة الذكية',
        subtitle: 'تشغيل المهام والعمليات',
        icon: Icons.smart_toy_rounded,
        accent: _green,
        route: '/automation',
      ),
      _ToolEntry(
        title: 'إنذار الفولتية',
        subtitle: 'مراقبة الطاقة والتنبيهات',
        icon: Icons.battery_alert_rounded,
        accent: _amber,
        route: '/voltage-alarm',
      ),
      _ToolEntry(
        title: 'نواة NOVA',
        subtitle: 'محرك التشخيص والتحكم',
        icon: Icons.memory_rounded,
        accent: _cyan,
        route: '/nova-core-engine',
      ),
    ],
  ),
  _ToolCategory(
    title: 'إدارة المنصة',
    description: 'الحسابات، الفوترة، وإعدادات التشغيل',
    icon: Icons.tune_rounded,
    accent: _amber,
    tools: <_ToolEntry>[
      _ToolEntry(
        title: 'الفوترة',
        subtitle: 'الذمم وسجلات الفوترة',
        icon: Icons.receipt_long_rounded,
        accent: _green,
        route: '/billing',
      ),
      _ToolEntry(
        title: 'الأدوار والصلاحيات',
        subtitle: 'إدارة الوصول للمستخدمين',
        icon: Icons.admin_panel_settings_rounded,
        accent: _pink,
        route: '/roles',
      ),
      _ToolEntry(
        title: 'مركز القيادة المداري',
        subtitle: 'رادار الارتباط ولوحات حالة الباكهول',
        icon: Icons.satellite_alt_rounded,
        accent: _cyan,
        route: '/orbital-uplink',
      ),
      _ToolEntry(
        title: 'وضع التحكم المطلق',
        subtitle: 'بروتوكولات الطوارئ — وضع العرض الآمن',
        icon: Icons.bolt_rounded,
        accent: _pink,
        route: '/god-mode',
      ),
      _ToolEntry(
        title: 'خزنة البيانات الكميّة',
        subtitle: 'واجهة النسخ الاحتياطي وسجل العمليات',
        icon: Icons.enhanced_encryption_rounded,
        accent: _cyan,
        route: '/quantum-backup',
      ),
      _ToolEntry(
        title: 'لوحة التحكم',
        subtitle: 'مركز محركات الشبكة والصيانة',
        icon: Icons.tune_rounded,
        accent: _cyan,
        route: '/control-panel',
      ),
      _ToolEntry(
        title: 'إعدادات النظام',
        subtitle: 'الاتصال وتفضيلات التطبيق',
        icon: Icons.settings_rounded,
        accent: _violet,
        route: '/settings',
      ),
    ],
  ),
];

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final categories = _toolCategories
        .map(
          (category) => _ToolCategory(
            title: category.title,
            description: category.description,
            icon: category.icon,
            accent: category.accent,
            tools: category.tools
                .where(
                  (tool) =>
                      query.isEmpty ||
                      tool.title.toLowerCase().contains(query) ||
                      tool.subtitle.toLowerCase().contains(query),
                )
                .toList(growable: false),
          ),
        )
        .where((category) => category.tools.isNotEmpty)
        .toList(growable: false);
    final columns = MediaQuery.sizeOf(context).width >= 720 ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: ParticleMatrixBg(
        particleCount: 38,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _cyan.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _cyan.withOpacity(0.55),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _cyan.withOpacity(0.14),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: _cyan,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'SAIF.NET / TOOL MATRIX',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'مركز الأدوات',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _green.withOpacity(0.28),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.circle, color: _green, size: 7),
                                SizedBox(width: 5),
                                Text(
                                  'READY',
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'كل أدوات إدارة الشبكة مرتبة ضمن مساحات واضحة، للوصول السريع إلى الوظائف التشغيلية.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.58),
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _searchField(),
                    ],
                  ),
                ),
              ),
              if (categories.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0x99101829),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cyan.withOpacity(0.18)),
                      ),
                      child: const Column(
                        children: <Widget>[
                          Icon(
                            Icons.search_off_rounded,
                            color: _cyan,
                            size: 36,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد أداة مطابقة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'جرّب اسمًا آخر أو كلمة أقصر.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9CA9BE),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              for (final category in categories) ...<Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _categoryHeading(category),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.91,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = category.tools[index];
                        return CyberToolCard(
                          title: tool.title,
                          subtitle: tool.subtitle,
                          icon: tool.icon,
                          accentColor: tool.accent,
                          onTap: () => context.go(tool.route),
                        );
                      },
                      childCount: category.tools.length,
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Center(
                    child: Text(
                      'NOVA  •  NETWORK OPERATIONS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _searchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0x88101829),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyan.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _cyan,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'ابحث عن أداة أو وظيفة...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.38),
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _cyan,
            size: 21,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _categoryHeading(_ToolCategory category) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: category.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: category.accent.withOpacity(0.28)),
          ),
          child: Icon(category.icon, color: category.accent, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                category.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.46),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: category.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: category.accent.withOpacity(0.18)),
          ),
          child: Text(
            category.tools.length.toString().padLeft(2, '0'),
            style: TextStyle(
              color: category.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );
  }
}
