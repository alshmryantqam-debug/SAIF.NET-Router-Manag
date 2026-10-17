import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/connection_provider.dart';
import 'screens/add_hotspot_user_screen.dart';
import 'screens/automation_screens.dart';
import 'screens/advanced_ai_screens.dart';
import 'screens/add_pppoe_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/business_screens.dart';
import 'services/business_service.dart';
import 'screens/firewall_screen.dart';
import 'screens/hotspot_screen.dart';
import 'screens/interfaces_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pppoe_screen.dart';
import 'screens/routers_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/voucher_screen.dart';
import 'theme.dart';
import 'widgets/main_shell.dart';

final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final connected = ref.watch(connectedProvider);
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isPublic = loc == '/splash' || loc == '/login';

      if (!connected && !isPublic) return '/login';
      if (connected && loc == '/login') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BusinessGate(allowed: const [BusinessRole.manager], child: DashboardScreen()),
            ),
          ),
          GoRoute(
            path: '/hotspot',
            name: 'hotspot',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BusinessGate(allowed: const [BusinessRole.manager], child: HotspotScreen()),
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'hotspot.add',
                builder: (_, __) => const AddHotspotUserScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/pppoe',
            name: 'pppoe',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BusinessGate(allowed: const [BusinessRole.manager], child: PppoeScreen()),
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'pppoe.add',
                builder: (_, __) => const AddPppoeScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/voucher',
            name: 'voucher',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BusinessGate(allowed: const [BusinessRole.manager, BusinessRole.distributor], child: VoucherScreen()),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: BusinessGate(allowed: const [BusinessRole.manager], child: SettingsScreen()),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/routers',
        name: 'routers',
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager], child: RoutersListScreen()),
      ),
      GoRoute(
        path: '/terminal',
        name: 'terminal',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager], child: TerminalScreen()),
      ),
      GoRoute(
        path: '/interfaces',
        name: 'interfaces',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager, BusinessRole.technician], child: InterfacesScreen()),
      ),
      GoRoute(path: '/billing', name: 'billing', parentNavigatorKey: _rootKey, builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager], child: BillingScreen())),
      GoRoute(path: '/customer-portal', name: 'customer-portal', parentNavigatorKey: _rootKey, builder: (_, __) => const BusinessGate(allowed: [BusinessRole.customer], child: CustomerPortalScreen())),
      GoRoute(path: '/roles', name: 'roles', parentNavigatorKey: _rootKey, builder: (_, __) => const BusinessRoleScreen()),
      GoRoute(
        path: '/advanced-ai',
        name: 'advanced-ai',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager, BusinessRole.technician], child: AdvancedAiScreen()),
      ),
      GoRoute(
        path: '/automation',
        name: 'automation',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager, BusinessRole.technician], child: AutomationHubScreen()),
      ),
      GoRoute(
        path: '/firewall',
        name: 'firewall',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BusinessGate(allowed: [BusinessRole.manager, BusinessRole.technician], child: FirewallScreen()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'الصفحة غير موجودة',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/splash'),
                child: const Text('العودة للبداية'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});