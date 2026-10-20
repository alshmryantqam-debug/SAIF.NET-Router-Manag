import 'package:flutter/material.dart';
import 'core/theme/nova_theme.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF1D1F2D);
  static const Color primaryColor = Color(0xFF6484D7);
  static const Color cardColor = Color(0xFF25293A);
  static const Color cardBorderColor = Color(0xFF3B4055);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B4C4);
  static const Color successColor = Color(0xFF55A99B);
  static const Color dangerColor = Color(0xFFD96A78);
  static const Color warningColor = Color(0xFFE2B65C);

  // Backward-compatible aliases used by existing screens and widgets.
  // Keep these mapped to the new blue theme so existing UI keeps compiling.
  static const Color bgDark = backgroundColor;
  static const Color primaryPurple = primaryColor;
  static const Color primaryBlue = primaryColor;
  static const Color cardDark = cardColor;
  static const Color textMain = textPrimary;
  static const Color textMuted = textSecondary;
  static const Color successGreen = successColor;
  static const Color dangerRed = dangerColor;

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B4562), Color(0xFF252A3D)],
  );

  static ThemeData get darkTheme => novaTheme();

  /* Legacy theme kept below for reference only.
  static ThemeData get legacyDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        surface: cardColor,
        background: backgroundColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }
  */
}
