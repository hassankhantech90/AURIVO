import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../products/domain/entities/attribute.dart';
import '../providers/admin_catalog_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import 'widgets/attribute_form_sheet.dart';

/// Admin attribute manager: full attribute list with create / edit / delete;
/// tap an attribute to manage its values.
class AdminAttributesPage extends ConsumerStatefulWidget {
  const AdminAttributesPage({super.key});

  @override
  ConsumerState<AdminAttributesPage> createState() =>
      _AdminAttributesPageState();
}

class _AdminAttributesPageState extends ConsumerState<AdminAttributesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(adminAttributesProvider.notifier).load();

  Future<void> _delete(Attribute a) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete attribute?',
      message: 'Delete "${a.name}" and hide it from filters.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    final error = await ref.read(adminAttributesProvider.notifier).remove(a.id);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Attribute deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAttributesProvider);
    final attributes = state.data;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AttributeFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New attribute'),
      ),
      appBar: const LuxuryAppBar(title: 'Attributes', showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial ||
          AdminStatus.loading when attributes.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when attributes.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load attributes.',
                onRetry: _load,
              ),
            ],
          ),
          _ when attributes.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No attributes yet',
                message: 'Tap "New attribute" to add one.',
                icon: Icons.tune_outlined,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: attributes.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final a = attributes[index];
              return LuxuryCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(a.name),
                  subtitle: Text(
                    '${a.dataType}${a.isFilterable ? ' · filterable' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'edit' => AttributeFormSheet.show(context, initial: a),
                      'values' => context.push(
                        AppRoutes.adminAttributeValuesPath(a.id),
                        extra: a.name,
                      ),
                      _ => _delete(a),
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'values', child: Text('Values')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => context.push(
                    AppRoutes.adminAttributeValuesPath(a.id),
                    extra: a.name,
                  ),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
