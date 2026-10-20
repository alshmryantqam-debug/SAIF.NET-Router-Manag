import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaColors {
  static const bg = Color(0xFF1D1F2D);
  static const surface = Color(0xFF25293A);
  static const surface2 = Color(0xFF303448);
  static const border = Color(0xFF3B4055);
  static const primary = Color(0xFF6484D7);
  static const violet = Color(0xFF7589D8);
  static const success = Color(0xFF55A99B);
  static const warn = Color(0xFFE2B65C);
  static const danger = Color(0xFFD96A78);
  static const text = Color(0xFFF0F1F6);
  static const muted = Color(0xFFB0B4C4);
  static const gradient = LinearGradient(
    colors: [Color(0xFF3B4562), Color(0xFF252A3D)],
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
      backgroundColor: const Color(0xFF191B28),
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
