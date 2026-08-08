import 'package:aurivo/core/theme/colors.dart';
import 'package:aurivo/core/theme/radius.dart';
import 'package:aurivo/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Helper for presenting rounded draggable luxury bottom sheets.
class LuxuryBottomSheet {
  const LuxuryBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: true,
      backgroundColor: AppColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.25,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: builder(context),
          );
        },
      ),
    );
  }
}
