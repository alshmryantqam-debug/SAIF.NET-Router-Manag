import 'package:flutter/material.dart';

/// Shared visual language for SAIF.NET. Kept dependency-free so the first
/// frame can render without waiting for network or platform services.
class AppColors {
  static const bgDeep = Color(0xFF070914);
  static const bgSurface = Color(0xFF0D1222);
  static const bgCard = Color(0xFF121A2C);
  static const bgElevated = Color(0xFF1B2540);
  static const glass = Color(0xE6121B2D);
  static const border = Color(0xFF2A3855);
  static const primary = Color(0xFFB9A2FF);
  static const primaryStrong = Color(0xFF7657F6);
  static const secondary = Color(0xFF56E4F4);
  static const accent = Color(0xFFFFD28A);
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
    colors: [Color(0xFF202A46), Color(0xFF11182A)],
  );

  static const primary = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFD5C7FF), Color(0xFF9A7BFF), Color(0xFF5A43D6)],
  );

  static const command = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF273052), Color(0xFF151D31), Color(0xFF0D1222)],
  );

  static const aqua = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF8AF4F0), Color(0xFF42BBD9)],
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
