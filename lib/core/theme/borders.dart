import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';

/// Border tokens and shapes for inputs, cards, and elevated surfaces.
class AppBorders {
  const AppBorders._();

  static const subtle = BorderSide(color: AppColors.softGrey);
  static const gold = BorderSide(color: AppColors.primaryGold);
  static const error = BorderSide(color: AppColors.error);
  static const success = BorderSide(color: AppColors.success);

  static OutlineInputBorder input({BorderSide side = subtle}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: side,
    );
  }

  static RoundedRectangleBorder rounded([double radius = AppRadius.lg]) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }
}
