import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'providers/cyber_defense_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hotspot_provider.dart';
import 'providers/pppoe_provider.dart';
import 'providers/sessions_provider.dart';
import 'screens/auth/app_login_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionProvider>(
          create: (_) => ConnectionProvider(),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, DashboardProvider>(
          create: (context) =>
              DashboardProvider(context.read<ConnectionProvider>()),
          update: (context, connectionProvider, dashboardProvider) {
            if (dashboardProvider == null) {
              return DashboardProvider(connectionProvider);
            }
            dashboardProvider.updateConnectionProvider(connectionProvider);
            return dashboardProvider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, PppoeProvider>(
          create: (context) =>
              PppoeProvider(context.read<ConnectionProvider>()),
          update: (context, connectionProvider, pppoeProvider) {
            if (pppoeProvider == null) {
              return PppoeProvider(connectionProvider);
            }
            pppoeProvider.updateConnectionProvider(connectionProvider);
            return pppoeProvider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, CyberDefenseProvider>(
          create: (context) =>
              CyberDefenseProvider(context.read<ConnectionProvider>()),
          update: (context, connectionProvider, cyberDefenseProvider) =>
              cyberDefenseProvider ?? CyberDefenseProvider(connectionProvider),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, SessionsProvider>(
          create: (context) =>
              SessionsProvider(context.read<ConnectionProvider>()),
          update: (context, connectionProvider, sessionsProvider) =>
              sessionsProvider ?? SessionsProvider(connectionProvider),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, HotspotProvider>(
          create: (context) =>
              HotspotProvider(context.read<ConnectionProvider>()),
          update: (context, connectionProvider, hotspotProvider) =>
              hotspotProvider ?? HotspotProvider(connectionProvider),
        ),
      ],
      child: const NovaApp(),
    ),
  );
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نوڨا NOVA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppLoginScreen(),
    );
  }
}
