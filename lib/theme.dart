import 'package:flutter/material.dart';

class AppColors {
  static const bgDeep = Color(0xFF0B1118);
  static const bgSurface = Color(0xFF111B24);
  static const bgCard = Color(0xFF17232D);
  static const bgElevated = Color(0xFF20313D);
  static const glass = Color(0xCC182630);
  static const border = Color(0xFF2B3D49);
  static const primary = Color(0xFF36C6B4);
  static const secondary = Color(0xFF64B5F6);
  static const accent = Color(0xFFFFB86B);
  static const success = Color(0xFF45D6A1);
  static const warning = Color(0xFFFFB454);
  static const danger = Color(0xFFFF647C);
  static const textPrimary = Color(0xFFF3F7FA);
  static const textSecondary = Color(0xFFB5C3CD);
  static const textMuted = Color(0xFF8295A2);
}

class AppGradients {
  static const glass = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xCC243642), Color(0xCC15232C)],
  );
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF52D8C6), Color(0xFF168D91), Color(0xFF225C76)],
  );
}

class AppDurations {
  static const normal = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}

class AppShadows {
  static List<BoxShadow> get soft => const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))];
  static List<BoxShadow> glow(Color color, {double opacity = 0.25}) => [
    BoxShadow(color: color.withOpacity(opacity), blurRadius: 24, spreadRadius: 1),
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
