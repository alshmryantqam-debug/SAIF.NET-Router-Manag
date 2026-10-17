import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class _Dest {
  const _Dest(this.route, this.icon, this.label);
  final String route;
  final IconData icon;
  final String label;
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const List<_Dest> _destinations = <_Dest>[
    _Dest('/dashboard', Icons.dashboard_rounded, 'القيادة'),
    _Dest('/hotspot', Icons.wifi_rounded, 'Hotspot'),
    _Dest('/pppoe', Icons.cable_rounded, 'PPPoE'),
    _Dest('/voucher', Icons.confirmation_number_rounded, 'الكروت'),
    _Dest('/settings', Icons.settings_rounded, 'الإعدادات'),
  ];

  int _indexOf(String location) {
    final i = _destinations.indexWhere((d) => location.startsWith(d.route));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(location);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBody: true,
      drawer: _buildDrawer(context),
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xF21A1429),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(.22)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.38), blurRadius: 24, offset: const Offset(0, 7)),
              BoxShadow(color: AppColors.primary.withOpacity(.05), blurRadius: 22, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: List.generate(_destinations.length, (i) {
              final d = _destinations[i];
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go(d.route),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: selected ? AppGradients.primary : null,
                      color: selected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: selected ? AppShadows.glow(AppColors.primary, opacity: .16) : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d.icon, size: 21, color: selected ? Colors.white : AppColors.textMuted),
                        const SizedBox(height: 4),
                        Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textMuted,
                            fontSize: 9.5,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 170,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppGradients.primary,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TikPlus ULTRA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'المنصة الاحترافية لإدارة MikroTik',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(context, icon: Icons.receipt_long_rounded, label: 'الفوترة', route: '/billing'),
          _drawerItem(context, icon: Icons.person_pin_circle_rounded, label: 'بوابة المشترك', route: '/customer-portal'),
          _drawerItem(context, icon: Icons.admin_panel_settings_rounded, label: 'الأدوار والصلاحيات', route: '/roles'),
          _drawerItem(
            context,
            icon: Icons.router_rounded,
            label: 'الراوترات',
            route: '/routers',
          ),
          _drawerItem(
            context,
            icon: Icons.terminal_rounded,
            label: 'Terminal',
            route: '/terminal',
          ),
          _drawerItem(
            context,
            icon: Icons.lan_rounded,
            label: 'الواجهات',
            route: '/interfaces',
          ),
          _drawerItem(
            context,
            icon: Icons.security_rounded,
            label: 'الجدار الناري',
            route: '/firewall',
          ),
          const Divider(color: AppColors.border, height: 24),
          _drawerItem(
            context,
            icon: Icons.settings_rounded,
            label: 'الإعدادات',
            route: '/settings',
          ),
          const Divider(color: AppColors.border, height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'TikPlus ULTRA · v1.0.0',
              style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = location.startsWith(route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        selected: selected,
        selectedTileColor: AppColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      ),
    );
  }
}