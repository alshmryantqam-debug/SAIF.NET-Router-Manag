import 'package:flutter/material.dart';

class AppColors {
  static const bgDeep = Color(0xFF0D1020);
  static const bgSurface = Color(0xFF151A2B);
  static const bgCard = Color(0xFF1A2033);
  static const bgElevated = Color(0xFF242B40);
  static const glass = Color(0xCC1B2236);
  static const border = Color(0xFF303A52);
  static const primary = Color(0xFFB49AFF);
  static const secondary = Color(0xFF66D9D0);
  static const accent = Color(0xFFF2C879);
  static const success = Color(0xFF45D6A1);
  static const warning = Color(0xFFFFB454);
  static const danger = Color(0xFFFF647C);
  static const textPrimary = Color(0xFFF8F5FF);
  static const textSecondary = Color(0xFFB8C1D8);
  static const textMuted = Color(0xFF8792AC);
}

class AppGradients {
  static const glass = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xCC252D45), Color(0xCC171D30)],
  );
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC3B2FF), Color(0xFF8C78D8), Color(0xFF536CB8)],
  );
}

class AppDurations {
  static const normal = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}

class AppShadows {
  static List<BoxShadow> get soft => const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))];
  static List<BoxShadow> glow(Color color, {double opacity = 0.25}) => [
    BoxShadow(color: color.withOpacity(opacity * 0.65), blurRadius: 18, spreadRadius: 0),
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
