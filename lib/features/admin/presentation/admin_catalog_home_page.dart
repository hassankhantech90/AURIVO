import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';

/// Admin catalog hub: entry points to manage categories, brands and attributes.
class AdminCatalogHomePage extends StatelessWidget {
  const AdminCatalogHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Catalog management',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _tile(
            context,
            icon: Icons.account_tree_outlined,
            title: 'Categories',
            subtitle: 'Category tree & visibility',
            route: AppRoutes.adminCategories,
          ),
          const SizedBox(height: AppSpacing.md),
          _tile(
            context,
            icon: Icons.sell_outlined,
            title: 'Brands',
            subtitle: 'Manage brands',
            route: AppRoutes.adminBrands,
          ),
          const SizedBox(height: AppSpacing.md),
          _tile(
            context,
            icon: Icons.tune_outlined,
            title: 'Attributes',
            subtitle: 'Attributes & their values',
            route: AppRoutes.adminAttributes,
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return LuxuryCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
