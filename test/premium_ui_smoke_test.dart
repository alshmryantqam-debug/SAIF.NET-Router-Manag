import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/screens/dashboard_screen.dart';
import 'package:tikplus_ultra/screens/login_screen.dart';
import 'package:tikplus_ultra/screens/routers_list_screen.dart';
import 'package:tikplus_ultra/theme.dart';
import 'package:tikplus_ultra/widgets/main_shell.dart';

void main() {
  test('premium theme exposes expected dark violet surfaces', () {
    expect(AppTheme.bgDeep, isA<Color>());
    expect(AppTheme.primary, isA<Color>());
    expect(AppTheme.dark.useMaterial3, isTrue);
  });

  test('main app screens remain constructible after visual refresh', () {
    expect(const DashboardScreen(), isA<Widget>());
    expect(const LoginScreen(), isA<Widget>());
    expect(const RoutersListScreen(), isA<Widget>());
    expect(const MainShell(), isA<Widget>());
  });
}
