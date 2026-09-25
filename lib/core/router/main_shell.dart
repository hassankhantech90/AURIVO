import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/navigation/luxury_bottom_navigation_bar.dart';
import 'app_routes.dart';

/// Persistent shell for the app's five primary destinations. Wraps the routed
/// [child] in a scaffold with the luxury bottom navigation bar; tapping a tab
/// switches destinations with [GoRouter.go]. Detail pages live on the root
/// navigator (outside this shell), so they open full-screen without the bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  /// The current location path (query stripped) used to highlight the tab.
  final String location;
  final Widget child;

  /// Tab route + icon + label, in bar order. Kept in one place so the index
  /// mapping and the rendered items can never drift apart.
  static const List<(String route, IconData icon, String label)> tabs = [
    (AppRoutes.home, Icons.home_outlined, 'Home'),
    (AppRoutes.explore, Icons.search, 'Explore'),
    (AppRoutes.wholesale, Icons.storefront_outlined, 'Wholesale'),
    (AppRoutes.orders, Icons.receipt_long_outlined, 'Orders'),
    (AppRoutes.profile, Icons.person_outline, 'Profile'),
  ];

  /// Index of the active tab; a pushed sub-location (e.g. a filtered Explore)
  /// still highlights its owning tab, and anything unmatched falls back to Home.
  int get _currentIndex {
    final index = tabs.indexWhere((tab) => tab.$1 == location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: LuxuryBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => context.go(tabs[index].$1),
        items: [
          for (final tab in tabs)
            LuxuryBottomNavItem(icon: tab.$2, label: tab.$3),
        ],
      ),
    );
  }
}
