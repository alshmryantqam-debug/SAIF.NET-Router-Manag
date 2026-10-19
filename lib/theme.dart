import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF0B0F19);
  static const Color primaryColor = Color(0xFF6B8CE6);
  static const Color cardColor = Color(0xFF161B2B);
  static const Color cardBorderColor = Color(0xFF2C3550);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A5BB);
  static const Color successColor = Color(0xFF4CAE7D);
  static const Color dangerColor = Color(0xFFD65C5C);
  static const Color warningColor = Color(0xFFE5C158);

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
    colors: [Color(0xFF3A4B75), Color(0xFF1F2A47)],
  );

  static ThemeData get darkTheme {
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
}
