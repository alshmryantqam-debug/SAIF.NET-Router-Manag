import 'package:flutter/material.dart';

class SaifTheme {
  SaifTheme._();

  // الألوان الأساسية المطابقة للثيم المطلوب
  static const Color scaffoldBg = Color(0xFF13151F);
  static const Color cardBg = Color(0xFF1C202E);
  static const Color cardBorder = Color(0xFF2C3246);
  static const Color circleBtnBg = Color(0xFF32394F);
  static const Color primaryBlue = Color(0xFF6782D4);
  static const Color accentGreen = Color(0xFF38B2AC);
  static const Color accentRed = Color(0xFFE5534B);
  static const Color accentAmber = Color(0xFFED8936);
  static const Color textWhite = Color(0xFFF7FAFC);
  static const Color textMuted = Color(0xFFA0AEC0);

  // تدرج البطاقة العلوية (الهيدر المنحني)
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF56638A),
      Color(0xFF394362),
      Color(0xFF282F47),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentGreen,
        surface: cardBg,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textWhite),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
      ),
    );
  }
}
