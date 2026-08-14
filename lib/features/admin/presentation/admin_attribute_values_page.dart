import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../products/domain/entities/attribute.dart';
import '../providers/admin_catalog_providers.dart';
import '../providers/admin_providers.dart' show AdminStatus;
import 'widgets/attribute_value_form_sheet.dart';

/// Admin manager for a single attribute's values.
class AdminAttributeValuesPage extends ConsumerStatefulWidget {
  const AdminAttributeValuesPage({
    super.key,
    required this.attributeId,
    this.attributeName,
  });

  final String attributeId;
  final String? attributeName;

  @override
  ConsumerState<AdminAttributeValuesPage> createState() =>
      _AdminAttributeValuesPageState();
}

class _AdminAttributeValuesPageState
    extends ConsumerState<AdminAttributeValuesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref
      .read(adminAttributeValuesProvider(widget.attributeId).notifier)
      .load();

  Future<void> _delete(AttributeValue v) async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete value?',
      message: 'Delete "${v.value}".',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (ok != true) return;
    final error = await ref
        .read(adminAttributeValuesProvider(widget.attributeId).notifier)
        .remove(v.id);
    if (!mounted) return;
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Value deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAttributeValuesProvider(widget.attributeId));
    final values = state.data;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AttributeValueFormSheet.show(
          context,
          attributeId: widget.attributeId,
        ),
        icon: const Icon(Icons.add),
        label: const Text('New value'),
      ),
      appBar: LuxuryAppBar(
        title: widget.attributeName ?? 'Values',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          AdminStatus.initial || AdminStatus.loading when values.isEmpty =>
            const Center(child: LoadingIndicator()),
          AdminStatus.failure when values.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load values.',
                onRetry: _load,
              ),
            ],
          ),
          _ when values.isEmpty => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyStateWidget(
                title: 'No values yet',
                message: 'Tap "New value" to add one.',
                icon: Icons.label_outline,
              ),
            ],
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final v = values[index];
              return LuxuryCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(v.value),
                  subtitle: Text('Sort ${v.sortOrder}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (m) => m == 'edit'
                        ? AttributeValueFormSheet.show(
                            context,
                            attributeId: widget.attributeId,
                            initial: v,
                          )
                        : _delete(v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => AttributeValueFormSheet.show(
                    context,
                    attributeId: widget.attributeId,
                    initial: v,
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
