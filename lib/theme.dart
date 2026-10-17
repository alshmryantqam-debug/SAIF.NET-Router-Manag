import 'package:flutter/material.dart';

class AppColors {
  static const bgDeep = Color(0xFF090713);
  static const bgSurface = Color(0xFF141021);
  static const bgCard = Color(0xFF1C172B);
  static const bgElevated = Color(0xFF251D38);
  static const glass = Color(0xCC211A32);
  static const border = Color(0xFF382B50);
  static const primary = Color(0xFFA56AFF);
  static const secondary = Color(0xFF5DCCFF);
  static const accent = Color(0xFFFFC46B);
  static const success = Color(0xFF45D6A1);
  static const warning = Color(0xFFFFB454);
  static const danger = Color(0xFFFF647C);
  static const textPrimary = Color(0xFFF8F5FF);
  static const textSecondary = Color(0xFFB9B0CC);
  static const textMuted = Color(0xFF827891);
}

class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC084FC), Color(0xFF7C3AED), Color(0xFF4F46E5)],
  );
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
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSurface,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgElevated,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
    ),
  );
}
