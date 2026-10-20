import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hotspot_provider.dart';
import 'providers/subscribers_provider.dart';
import 'providers/traffic_provider.dart';
import 'screens/auth/app_login_screen.dart';
import 'theme.dart';

void main() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectionProvider>(create: (_) => ConnectionProvider()),
      ChangeNotifierProxyProvider<ConnectionProvider, TrafficProvider>(
        create: (_) => TrafficProvider(),
        update: (context, connection, traffic) {
          final provider = traffic ?? TrafficProvider();
          provider.attach(connection.client);
          return provider;
        },
      ),
      ChangeNotifierProxyProvider<ConnectionProvider, DashboardProvider>(
        create: (_) => DashboardProvider(),
        update: (context, connection, dashboard) {
          final provider = dashboard ?? DashboardProvider();
          provider.attach(connection.client);
          return provider;
        },
      ),
      ChangeNotifierProxyProvider<ConnectionProvider, SubscribersProvider>(
        create: (_) => SubscribersProvider(),
        update: (context, connection, subscribers) {
          final provider = subscribers ?? SubscribersProvider();
          provider.attach(connection.client);
          return provider;
        },
      ),
      ChangeNotifierProxyProvider<ConnectionProvider, HotspotProvider>(
        create: (_) => HotspotProvider(),
        update: (context, connection, hotspot) {
          final provider = hotspot ?? HotspotProvider();
          provider.attach(connection.client);
          return provider;
        },
      ),
    ],
    child: const NovaApp(),
  ));
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SAIF.NET',
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
      textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
    home: const AppLoginScreen(),
  );
}
