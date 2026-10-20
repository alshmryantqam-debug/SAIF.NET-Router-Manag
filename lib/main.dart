import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/nova_theme.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hotspot_provider.dart';
import 'providers/subscribers_provider.dart';
import 'providers/traffic_provider.dart';
import 'screens/auth/app_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => ConnectionProvider()),
    ChangeNotifierProxyProvider<ConnectionProvider, TrafficProvider>(create: (_) => TrafficProvider(), update: (_, c, p) => (p ?? TrafficProvider())..attach(c.client)),
    ChangeNotifierProxyProvider<ConnectionProvider, DashboardProvider>(create: (_) => DashboardProvider(), update: (_, c, p) => (p ?? DashboardProvider())..attach(c.client)),
    ChangeNotifierProxyProvider<ConnectionProvider, SubscribersProvider>(create: (_) => SubscribersProvider(), update: (_, c, p) => (p ?? SubscribersProvider())..attach(c.client)),
    ChangeNotifierProxyProvider<ConnectionProvider, HotspotProvider>(create: (_) => HotspotProvider(), update: (_, c, p) => (p ?? HotspotProvider())..attach(c.client)),
  ], child: const NovaApp()));
}
class NovaApp extends StatelessWidget {
  const NovaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SAIF.NET', debugShowCheckedModeBanner: false, theme: novaTheme(),
    locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
    home: const AppLoginScreen(),
  );
}
