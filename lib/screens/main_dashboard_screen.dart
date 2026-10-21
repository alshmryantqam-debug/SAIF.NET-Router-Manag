import 'package:flutter/material.dart';

import 'dashboard_screen.dart';

/// Main production dashboard entry point.
///
/// DashboardScreen remains the source of truth for the existing navigation and
/// subscriber tools; its telemetry is powered by LiveDashboardProvider.
class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}
