import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/connection_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/main_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final connected = ref.watch(connectedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isPublic = loc == '/' || loc == '/login';

      if (!connected && !isPublic) return '/login';
      if (connected && loc == '/login') return '/app';
      return null;
    },
    routes: [
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
      GoRoute(
        path: '/app',
        name: 'app',
        builder: (context, state) => const MainShell(),
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
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF3B5C),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'الصفحة غير موجودة',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
