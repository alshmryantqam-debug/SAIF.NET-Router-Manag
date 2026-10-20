import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaColors {
  static const bg = Color(0xFF090B14);
  static const surface = Color(0xFF121726);
  static const surface2 = Color(0xFF1A2235);
  static const border = Color(0xFF2A3550);
  static const primary = Color(0xFF9875FF);
  static const violet = Color(0xFFC4B5FD);
  static const cyan = Color(0xFF63D7F5);
  static const success = Color(0xFF61D5B0);
  static const warn = Color(0xFFF5C66A);
  static const danger = Color(0xFFFF7788);
  static const text = Color(0xFFF5F6FC);
  static const muted = Color(0xFFA2ABC0);
  static const gradient = LinearGradient(
    colors: [Color(0xFF252144), Color(0xFF141B2B), Color(0xFF111625)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

ThemeData novaTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
    bodyColor: NovaColors.text,
    displayColor: NovaColors.text,
  );
  OutlineInputBorder outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color),
      );

  return base.copyWith(
    scaffoldBackgroundColor: NovaColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: NovaColors.primary,
      secondary: NovaColors.cyan,
      surface: NovaColors.surface,
      error: NovaColors.danger,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: NovaColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: NovaColors.text,
      ),
      iconTheme: const IconThemeData(color: NovaColors.text),
    ),
    cardTheme: CardThemeData(
      color: NovaColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: NovaColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0F1320),
      indicatorColor: NovaColors.primary.withOpacity(.18),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NovaColors.surface2,
      labelStyle: const TextStyle(color: NovaColors.muted),
      hintStyle: const TextStyle(color: NovaColors.muted),
      border: outline(NovaColors.border),
      enabledBorder: outline(NovaColors.border),
      focusedBorder: outline(NovaColors.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NovaColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}