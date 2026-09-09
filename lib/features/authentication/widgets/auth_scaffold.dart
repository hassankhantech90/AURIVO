import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';
import 'aurivo_logo.dart';

/// Keyboard-aware responsive authentication page shell.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softCream,
      // Auth surfaces are intentionally light (softCream page + white card) in
      // both themes, so force the on-light text theme for this subtree —
      // otherwise the dark TextTheme paints headings/labels white-on-light
      // (invisible). Colour-only: light/dark TextThemes share sizes/weights.
      // Scoped to AuthScaffold descendants; the global darkTextTheme is
      // untouched. Explicit colours (subtitle, buttons, links) are unaffected.
      body: Theme(
        data: Theme.of(
          context,
        ).copyWith(textTheme: AppTypography.lightTextTheme()),
        child: SafeArea(
          child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth >= 700
                ? 520.0
                : double.infinity;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showLogo) ...[
                          const AurivoLogo(compact: true),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.graphite,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        LuxuryCard(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
