import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One builder for both modes so they can't drift apart. Light mode is the
/// same look the app had before dark mode existed.
ThemeData buildAppTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2EC4B6),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: colors.bg,
    extensions: [colors],
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: colors.surface,
    ),
  );
}
