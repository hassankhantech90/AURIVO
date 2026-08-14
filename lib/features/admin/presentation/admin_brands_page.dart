import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../products/domain/entities/brand.dart';
import '../providers/admin_catalog_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import 'widgets/brand_form_sheet.dart';

/// Admin brand manager: full brand list with create / edit / archive.
class AdminBrandsPage extends ConsumerStatefulWidget {
  const AdminBrandsPage({super.key});

  @override
  ConsumerState<AdminBrandsPage> createState() => _AdminBrandsPageState();
}

class _AdminBrandsPageState extends ConsumerState<AdminBrandsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(adminBrandsProvider.notifier).load();

  Future<void> _delete(Brand b) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Archive brand?',
      message: 'Archive and hide "${b.name}".',
      confirmLabel: 'Archive',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    final error = await ref.read(adminBrandsProvider.notifier).remove(b.id);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Brand archived.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBrandsProvider);
    final brands = state.data;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BrandFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New brand'),
      ),
      appBar: const LuxuryAppBar(title: 'Brands', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when brands.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when brands.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load brands.',
                onRetry: _load,
              ),
            ],
          ),
          _ when brands.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No brands yet',
                message: 'Tap "New brand" to add one.',
                icon: Icons.sell_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: brands.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final b = brands[index];
              return LuxuryCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(b.name),
                  subtitle: Text('/${b.slug} · ${b.status}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit'
                        ? BrandFormSheet.show(context, initial: b)
                        : _delete(b),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Archive')),
                    ],
                  ),
                  onTap: () => BrandFormSheet.show(context, initial: b),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
