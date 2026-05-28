import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F172A);
  static const Color blue = Color(0xFF3A86FF);
  static const Color mint = Color(0xFF2EC4B6);
  static const Color coral = Color(0xFFFF6B6B);

  static Color whiteA(double alpha) => white.withValues(alpha: alpha);
  static Color inkA(double alpha) => ink.withValues(alpha: alpha);
  static Color blueA(double alpha) => blue.withValues(alpha: alpha);
  static Color mintA(double alpha) => mint.withValues(alpha: alpha);
  static Color coralA(double alpha) => coral.withValues(alpha: alpha);
}
