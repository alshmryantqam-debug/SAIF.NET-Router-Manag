import 'package:flutter/material.dart';

/// Shared NOVA visual system: midnight navy, electric violet and cyan. Kept dependency-free so the first
/// frame can render without waiting for network or platform services.
class AppColors {
  static const bgDeep = Color(0xFF050817);
  static const bgSurface = Color(0xFF0A1024);
  static const bgCard = Color(0xFF101831);
  static const bgElevated = Color(0xFF182345);
  static const glass = Color(0xE60A1530);
  static const border = Color(0xFF263B67);
  static const primary = Color(0xFFB56BFF);
  static const primaryStrong = Color(0xFF782BFF);
  static const secondary = Color(0xFF00D9FF);
  static const accent = Color(0xFFFF79B8);
  static const success = Color(0xFF54E6B0);
  static const warning = Color(0xFFFFC56F);
  static const danger = Color(0xFFFF6D91);
  static const textPrimary = Color(0xFFF5F7FF);
  static const textSecondary = Color(0xFFB8C4DA);
  static const textMuted = Color(0xFF8493AD);
}

class AppGradients {
  static const glass = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF17264B), Color(0xFF0C122A), Color(0xFF080C1D)],
  );

  static const primary = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFE7A0FF), Color(0xFF9C35FF), Color(0xFF5825FF)],
  );

  static const command = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF123B63), Color(0xFF101A3C), Color(0xFF080C1D)],
  );

  static const aqua = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF5CF5FF), Color(0xFF00B9F0)],
  );
}

class AppDurations {
  static const normal = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
}

class AppShadows {
  static List<BoxShadow> get soft => const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.22}) => [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 28,
          spreadRadius: 1,
        ),
      ];
}

class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

class AppTheme {
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDeep,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.bgCard,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDeep,
      foregroundColor: AppColors.textPrimary,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryStrong,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(44, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgElevated,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
      ),
      headlineSmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
