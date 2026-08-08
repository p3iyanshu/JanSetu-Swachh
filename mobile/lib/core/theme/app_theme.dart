import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentBlue,
        primary: accentBlue,
        secondary: accentOrange,
        background: backgroundColor,
        surface: cardColor,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primaryColor),
        bodyLarge: TextStyle(fontSize: 18, color: primaryColor),
        bodyMedium: TextStyle(fontSize: 16, color: primaryColor), // Min 16sp base font requirement
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56), // Minimum 48-56dp touch target
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
