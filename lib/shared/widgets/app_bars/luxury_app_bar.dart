import 'package:aurivo/core/theme/spacing.dart';
import 'package:flutter/material.dart';

import '../inputs/custom_search_bar.dart';

/// Reusable Pareezay.Hub app bar supporting large, small, search, back, and action variants.
class LuxuryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LuxuryAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.largeTitle = false,
    this.showBackButton = false,
    this.actions,
    this.searchController,
    this.searchHint = 'Search',
    this.onSearchChanged,
    this.toolbarHeight,
    this.bottom,
  });

  final String? title;

  /// A custom title widget (e.g. a branded wordmark + tagline). Takes
  /// precedence over [title] when provided.
  final Widget? titleWidget;
  final bool largeTitle;
  final bool showBackButton;
  final List<Widget>? actions;
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;

  /// Explicit toolbar height (e.g. to fit a two-line branded title). When null
  /// the default height is used, so existing app bars are unaffected.
  final double? toolbarHeight;

  /// Optional strip pinned under the toolbar (e.g. a mode toggle). Ignored
  /// when [searchController] is set, which owns the bottom slot.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    if (searchController != null) return const Size.fromHeight(116);
    return Size.fromHeight(
      (toolbarHeight ?? (largeTitle ? 96 : 64)) +
          (bottom?.preferredSize.height ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      toolbarHeight: searchController == null ? toolbarHeight : null,
      title:
          titleWidget ??
          (title == null
              ? null
              : Text(
                  title!,
                  style: largeTitle
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.titleLarge,
                )),
      actions: actions,
      bottom: searchController == null
          ? bottom
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
