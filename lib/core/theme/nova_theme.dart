import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaColors {
  static const bg = Color(0xFF070B14);
  static const surface = Color(0xFF0E1626);
  static const surface2 = Color(0xFF141F36);
  static const border = Color(0xFF22304F);
  static const primary = Color(0xFF5B8CFF);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF22C55E);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const text = Color(0xFFE8EEFF);
  static const muted = Color(0xFF8A97B5);
  static const gradient = LinearGradient(
    colors: [primary, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData novaTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final t = GoogleFonts.cairoTextTheme(base.textTheme)
      .apply(bodyColor: NovaColors.text, displayColor: NovaColors.text);
  OutlineInputBorder ob(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
  return base.copyWith(
    scaffoldBackgroundColor: NovaColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: NovaColors.primary,
      secondary: NovaColors.violet,
      surface: NovaColors.surface,
      error: NovaColors.danger,
    ),
    textTheme: t,
    appBarTheme: AppBarTheme(
      backgroundColor: NovaColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NovaColors.surface,
      indicatorColor: NovaColors.primary.withOpacity(0.18),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(t.labelMedium),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NovaColors.surface2,
      border: ob(NovaColors.border),
      enabledBorder: ob(NovaColors.border),
      focusedBorder: ob(NovaColors.primary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NovaColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
