import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/router_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/hotspot_screen.dart';
import 'screens/pppoe_screen.dart';
import 'screens/voucher_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/main_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(connectionStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isConnected = authState.isConnected;
      final location = state.matchedLocation;

      final isPublicRoute = location == '/' || location == '/login';

      // غير متصل ويحاول دخول شاشة محمية → إلى /login
      if (!isConnected && !isPublicRoute) return '/login';

      // متصل ويحاول الدخول لـ /login → إلى /app/dashboard
      if (isConnected && location == '/login') return '/app/dashboard';

      return null;
    },
    routes: [
      // ═══════════════ المسارات العامة ═══════════════
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ═══════════════ المسارات المحمية ═══════════════
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/app/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/app/hotspot',
            name: 'hotspot',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HotspotScreen(),
            ),
          ),
          GoRoute(
            path: '/app/pppoe',
            name: 'pppoe',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PppoeScreen(),
            ),
          ),
          GoRoute(
            path: '/app/voucher',
            name: 'voucher',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VoucherScreen(),
            ),
          ),
          GoRoute(
            path: '/app/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF05080F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF3B5C), size: 64),
              const SizedBox(height: 16),
              const Text(
                'الصفحة غير موجودة',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('العودة للبداية'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
