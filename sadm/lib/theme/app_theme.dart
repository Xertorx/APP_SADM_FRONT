import 'package:flutter/material.dart';

/// Soft pastel palette: mint green, cream and peach.
class AppPalette {
  AppPalette._();

  static const mint = Color(0xFFB8E3D2);
  static const mintDark = Color(0xFF6FAE9B);
  static const cream = Color(0xFFFBF3E7);
  static const peach = Color(0xFFF6C8A8);
  static const peachDark = Color(0xFFE79A6D);
  static const textDark = Color(0xFF4A4238);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppPalette.mintDark,
    primary: AppPalette.mintDark,
    secondary: AppPalette.peachDark,
    surface: AppPalette.cream,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.cream,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.mint,
      foregroundColor: AppPalette.textDark,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: AppPalette.mintDark.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.cream.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppPalette.mintDark.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.mintDark, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.peachDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme().apply(
      bodyColor: AppPalette.textDark,
      displayColor: AppPalette.textDark,
    ),
  );
}
