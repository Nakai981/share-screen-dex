import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF18313F);
  static const muted = Color(0xFF74838C);
  static const paper = Color(0xFFF5F7F9);
  static const blue = Color(0xFF3864DE);
  static const line = Color(0xFFE2E8ED);
  static const mint = Color(0xFFA6D4CA);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'BeVietnamPro',
  scaffoldBackgroundColor: AppColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    primary: AppColors.blue,
    surface: Colors.white,
    onSurface: AppColors.ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -.9,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 13, height: 1.65),
    bodySmall: TextStyle(fontSize: 11, height: 1.5),
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  dividerColor: AppColors.line,
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: AppColors.ink),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.paper,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(18),
  ),
);
