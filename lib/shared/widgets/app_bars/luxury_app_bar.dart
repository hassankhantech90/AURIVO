import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import '../inputs/custom_search_bar.dart';

/// Reusable AURIVO app bar supporting large, small, search, back, and action variants.
class LuxuryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LuxuryAppBar({
    super.key,
    this.title,
    this.largeTitle = false,
    this.showBackButton = false,
    this.actions,
    this.searchController,
    this.searchHint = 'Search',
    this.onSearchChanged,
  });

  final String? title;
  final bool largeTitle;
  final bool showBackButton;
  final List<Widget>? actions;
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;

  @override
  Size get preferredSize =>
      Size.fromHeight(searchController == null ? (largeTitle ? 96 : 64) : 116);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      title: title == null
          ? null
          : Text(
              title!,
              style: largeTitle
                  ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.titleLarge,
            ),
      actions: actions,
      bottom: searchController == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: CustomSearchBar(
                  controller: searchController,
                  hintText: searchHint,
                  onChanged: onSearchChanged,
                ),
              ),
            ),
    );
  }
}
