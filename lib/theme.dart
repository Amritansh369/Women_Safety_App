import 'package:flutter/material.dart';

/// Central color palette & theme for SafeHer.
class AppColors {
  static const primary = Color(0xFF8E2157);   // brand plum - calm, trustworthy brand color
  static const primaryDark = Color(0xFF5E1239);
  static const rose = Color(0xFFD9537F);      // warm secondary accent
  static const accent = Color(0xFF5B57D1);    // violet for location features
  static const bg = Color(0xFFFCF7F9);
  static const bgDark = Color(0xFF17121A);
  static const surfaceDark = Color(0xFF241C29);
  static const sosRed = Color(0xFFD32029);
  static const sosRedDark = Color(0xFF8F1219);
  static const success = Color(0xFF1F7A3D);
  static const warning = Color(0xFFB25E00);
  static const textDark = Color(0xFF241A22);
}

ThemeData buildAppTheme() => _build(Brightness.light);

ThemeData buildDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: dark ? const Color(0xFFF2A9C7) : AppColors.primary,
    secondary: dark ? const Color(0xFFC3C0FF) : AppColors.accent,
    surface: dark ? AppColors.surfaceDark : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bg,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.bgDark : AppColors.bg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.surfaceDark : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    fontFamily: 'Roboto',
  );
}
