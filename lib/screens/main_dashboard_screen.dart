/// Backwards-compatible entry point for the app's existing dashboard.
///
/// The existing dashboard contains the subscriber and network-management
/// shortcuts; keeping it as the single implementation prevents feature loss.
export 'dashboard_screen.dart' show DashboardScreen;

import 'dashboard_screen.dart';

typedef MainDashboardScreen = DashboardScreen;
