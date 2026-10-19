import 'package:flutter/material.dart';

/// Shared app shell. Adopt gradually after checking existing routing and providers.
class SaifApp extends StatelessWidget {
  const SaifApp({super.key, required this.home, required this.theme});

  final Widget home;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: home,
      );
}