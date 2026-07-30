import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Search input styled for marketplace discovery and filtering.
class CustomSearchBar extends StatelessWidget {
  const CustomSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: hintText,
      leading: const Icon(Icons.search),
      trailing: onClear == null
          ? null
          : [IconButton(onPressed: onClear, icon: const Icon(Icons.close))],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(AppColors.pureWhite),
      side: const WidgetStatePropertyAll(AppBorders.subtle),
      shape: WidgetStatePropertyAll(AppBorders.rounded(AppRadius.pill)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
    );
  }
}
