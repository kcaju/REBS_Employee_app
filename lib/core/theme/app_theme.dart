import 'package:flutter/material.dart';

class AppTheme {
  // Deep dark purple palette matching the background
  static const Color darkBg = Color(0xFF150D2A);
  static const Color cardBg = Color(0xFF25164E);
  static const Color cardBgTranslucent = Color(0xD925164E);
  static const Color cardBorder = Color(0x26FFFFFF);

  // Accents from the uploaded design
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color purplePrimary = Color(0xFF8B5CF6);
  static const Color purpleDark = Color(0xFF6D28D9);
  static const Color purpleDeep = Color(0xFF4C1D95);

  static const Color cyanAccent = Color(0xFF22D3EE);
  static const Color amberAccent = Color(0xFFFB923C);
  static const Color blueAccent = Color(0xFF60A5FA);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB8A9D9);
  static const Color textMuted = Color(0xFF8E7EAF);

  static BoxDecoration boxDecoration({
    double radius = 22,
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? cardBgTranslucent,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? cardBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.dark(
        primary: purplePrimary,
        secondary: cyanAccent,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerColor: Colors.white12,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }
}
