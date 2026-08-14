import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../categories/domain/entities/category.dart';
import '../providers/admin_catalog_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import 'widgets/category_form_sheet.dart';

/// Admin category manager: the full category list (active + inactive) with
/// create / edit / soft-delete.
class AdminCategoriesPage extends ConsumerStatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  ConsumerState<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends ConsumerState<AdminCategoriesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(adminCategoriesProvider.notifier).load();

  Future<void> _edit([Category? initial]) => CategoryFormSheet.show(
    context,
    initial: initial,
    categories: ref.read(adminCategoriesProvider).data,
  );

  Future<void> _delete(Category c) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete category?',
      message: 'Deactivate and hide "${c.name}". You can recreate it later.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    final error = await ref.read(adminCategoriesProvider.notifier).remove(c.id);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Category deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCategoriesProvider);
    final categories = state.data;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      appBar: const LuxuryAppBar(title: 'Categories', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial ||
          AdminStatus.loading when categories.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when categories.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load categories.',
                onRetry: _load,
              ),
            ],
          ),
          _ when categories.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No categories yet',
                message: 'Tap "New category" to add one.',
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final c = categories[index];
              return LuxuryCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text('/${c.slug}'),
                  leading: c.isRoot
                      ? const Icon(Icons.folder_outlined)
                      : const Icon(Icons.subdirectory_arrow_right),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!c.isActive)
                        const LuxuryBadge(
                          label: 'Inactive',
                          backgroundColor: AppColors.softGrey,
                          foregroundColor: AppColors.charcoal,
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'edit' ? _edit(c) : _delete(c),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _edit(c),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
