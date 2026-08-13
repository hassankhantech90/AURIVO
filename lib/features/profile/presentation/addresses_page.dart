import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/address.dart';
import '../providers/profile_providers.dart';
import 'widgets/address_form_sheet.dart';

/// Manages the buyer's saved shipping addresses (list, add, edit, set default,
/// delete). Backed by [addressesProvider] (owner-scoped RLS).
class AddressesPage extends ConsumerStatefulWidget {
  const AddressesPage({super.key});

  @override
  ConsumerState<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends ConsumerState<AddressesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(addressesProvider.notifier).load();

  Future<void> _delete(Address address) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete address?',
      message: 'This removes the saved address.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    await ref.read(addressesProvider.notifier).deleteAddress(address.id);
    if (!mounted) return;
    final state = ref.read(addressesProvider);
    if (state.status == ProfileViewStatus.failure) {
      LuxurySnackBars.error(context, state.message ?? 'Could not delete.');
    }
  }

  Future<void> _setDefault(Address address) async {
    await ref.read(addressesProvider.notifier).setDefaultAddress(address.id);
    if (!mounted) return;
    final state = ref.read(addressesProvider);
    if (state.status == ProfileViewStatus.failure) {
      LuxurySnackBars.error(context, state.message ?? 'Could not update.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressesProvider);
    final addresses = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Addresses', showBackButton: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddressFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: switch (state.status) {
          ProfileViewStatus.initial || ProfileViewStatus.loading
              when state.data == null =>
            const Center(child: LoadingIndicator()),
          ProfileViewStatus.failure when state.data == null => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load your addresses.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            addresses.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No addresses yet',
                        message: 'Add a shipping address to speed up checkout.',
                        icon: Icons.location_on_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return _AddressTile(
                        address: address,
                        onEdit: () =>
                            AddressFormSheet.show(context, initial: address),
                        onSetDefault: () => _setDefault(address),
                        onDelete: () => _delete(address),
                      );
                    },
                  ),
        },
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      address.addressLine1,
      if (address.addressLine2 != null && address.addressLine2!.isNotEmpty)
        address.addressLine2!,
      if (address.area != null && address.area!.isNotEmpty) address.area!,
      '${address.city}, ${address.province}',
      if (address.postalCode != null && address.postalCode!.isNotEmpty)
        address.postalCode!,
      address.country,
    ];
    return LuxuryCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  address.label?.isNotEmpty == true
                      ? address.label!
                      : address.recipientName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (address.isDefault) const LuxuryBadge(label: 'Default'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(address.recipientName, style: theme.textTheme.bodySmall),
          Text(address.phone, style: theme.textTheme.bodySmall),
          Text(lines.join(', '), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (!address.isDefault)
                LuxuryTextButton(label: 'Set default', onPressed: onSetDefault),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
