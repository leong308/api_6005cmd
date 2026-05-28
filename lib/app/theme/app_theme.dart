import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.45,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.45,
      ),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppPalette.blue,
        secondary: AppPalette.mint,
        tertiary: AppPalette.coral,
        surface: AppPalette.white,
        onSurface: AppPalette.ink,
        onPrimary: AppPalette.white,
        onSecondary: AppPalette.white,
        onTertiary: AppPalette.white,
        error: AppPalette.coral,
        onError: AppPalette.white,
      ),
      scaffoldBackgroundColor: AppPalette.white,
      textTheme: textTheme.apply(fontFamily: 'SF Pro Text'),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.whiteA(0),
        surfaceTintColor: AppPalette.whiteA(0),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppPalette.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.blueA(0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppPalette.inkA(0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.blue),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: AppPalette.mintA(0.4)),
        selectedColor: AppPalette.mintA(0.22),
        backgroundColor: AppPalette.whiteA(0.92),
      ),
      dividerTheme: DividerThemeData(color: AppPalette.inkA(0.12)),
    );
  }
}
