import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Item model for the reusable luxury bottom navigation bar.
class LuxuryBottomNavItem {
  const LuxuryBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Five-tab bottom navigation bar with animated gold indicator.
class LuxuryBottomNavigationBar extends StatelessWidget {
  const LuxuryBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(
         items.length == 5,
         'LuxuryBottomNavigationBar supports exactly five tabs.',
       );

  final List<LuxuryBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.softGrey),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;

            // Icon-only visually, so the label is exposed to screen readers
            // (and as a long-press tooltip) for accessibility.
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                excludeSemantics: true,
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: AnimatedContainer(
                      duration: AppDurations.normal,
                      curve: AppAnimations.standard,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGold.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color: selected
                                ? AppColors.deepGold
                                : AppColors.mediumGrey,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AnimatedContainer(
                            duration: AppDurations.normal,
                            width: selected ? 18 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
