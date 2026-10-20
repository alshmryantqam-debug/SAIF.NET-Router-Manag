import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/nova_theme.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hotspot_provider.dart';
import 'providers/subscribers_provider.dart';
import 'providers/traffic_provider.dart';
import 'screens/auth/router_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProxyProvider<ConnectionProvider, TrafficProvider>(
          create: (_) => TrafficProvider(),
          update: (_, connection, previous) =>
              (previous ?? TrafficProvider())..attach(connection.client),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, connection, previous) =>
              (previous ?? DashboardProvider())..attach(connection.client),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, SubscribersProvider>(
          create: (_) => SubscribersProvider(),
          update: (_, connection, previous) =>
              (previous ?? SubscribersProvider())..attach(connection.client),
        ),
        ChangeNotifierProxyProvider<ConnectionProvider, HotspotProvider>(
          create: (_) => HotspotProvider(),
          update: (_, connection, previous) =>
              (previous ?? HotspotProvider())..attach(connection.client),
        ),
      ],
      child: const NovaApp(),
    ),
  );
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NOVA | إدارة الشبكة',
        debugShowCheckedModeBanner: false,
        theme: novaTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (_, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        // One clear entry point: router connection. The old extra PIN screen
        // made users pass through two unrelated login screens.
        home: const RouterLoginScreen(),
      );
}