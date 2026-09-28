import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/design_system.dart';
import '../../../profile/domain/entities/address.dart';
import '../../../profile/providers/profile_providers.dart';

/// Bottom sheet to choose a shipping address; pops the chosen address id (or
/// null if dismissed). When the buyer has no saved addresses it prompts them to
/// add one and routes to the Addresses screen.
class AddressPickerSheet extends ConsumerStatefulWidget {
  const AddressPickerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return LuxuryBottomSheet.show<String>(
      context: context,
      builder: (_) => const AddressPickerSheet(),
    );
  }

  @override
  ConsumerState<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends ConsumerState<AddressPickerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(addressesProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressesProvider);
    final addresses = state.data ?? const <Address>[];
    final loading =
        state.status == ProfileViewStatus.loading && state.data == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ship to', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: LoadingIndicator()),
          )
        else if (addresses.isEmpty)
          _NoAddresses(
            onAdd: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.addresses);
            },
          )
        else
          for (final address in addresses)
            _AddressOption(
              address: address,
              onTap: () => Navigator.of(context).pop(address.id),
            ),
      ],
    );
  }
}

class _NoAddresses extends StatelessWidget {
  const _NoAddresses({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You have no saved addresses yet. Add one to place the order.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(label: 'Add an address', onPressed: onAdd),
        ),
      ],
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({required this.address, required this.onTap});

  final Address address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LuxuryCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
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
                      if (address.isDefault)
                        const LuxuryBadge(label: 'Default'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${address.addressLine1}, ${address.city}, '
                    '${address.province}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
          ],
        ),
      ),
    );
  }
}
