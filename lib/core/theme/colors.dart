import 'package:flutter/material.dart';

/// Central luxury color palette for the Pareezay.Hub design system.
class AppColors {
  const AppColors._();

  static const primaryGold = Color(0xFFC9A227);
  static const champagneGold = Color(0xFFE4C76B);
  static const deepGold = Color(0xFF9F7A16);
  static const antiqueGold = Color(0xFFB08D2D);
  static const creamBackground = Color(0xFFFFFAF0);
  static const softCream = Color(0xFFFAF7F2);
  static const ivory = Color(0xFFFFFCF7);
  static const porcelain = Color(0xFFF8F5EF);
  static const pureWhite = Color(0xFFFFFFFF);
  static const jetBlack = Color(0xFF111111);
  static const obsidian = Color(0xFF050505);
  static const charcoal = Color(0xFF262626);
  static const graphite = Color(0xFF3A3A3A);
  static const softGrey = Color(0xFFE7E3DA);
  static const mistGrey = Color(0xFFF0EEE8);
  static const mediumGrey = Color(0xFF8C8C8C);
  static const success = Color(0xFF2E7D5B);
  static const warning = Color(0xFFB7791F);
  static const info = Color(0xFF2F5F8F);
  static const error = Color(0xFFB3261E);

  static const goldGradient = LinearGradient(
    colors: [champagneGold, primaryGold, deepGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
