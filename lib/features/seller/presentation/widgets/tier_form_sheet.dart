import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/price_tier.dart';
import '../../domain/entities/price_tier_draft.dart';
import '../../providers/seller_tier_providers.dart';

/// Modal bottom-sheet form to create or edit a wholesale price tier. Presented
/// via [LuxuryBottomSheet]; submits through [productTiersProvider]. Returns
/// `true` through the sheet when a tier was saved.
class TierFormSheet extends ConsumerStatefulWidget {
  const TierFormSheet({
    super.key,
    required this.productId,
    this.initial,
    this.takenQuantities = const {},
  });

  final String productId;
  final PriceTier? initial;

  /// Minimum quantities already used by other tiers, to catch duplicates
  /// before hitting the unique constraint.
  final Set<int> takenQuantities;

  static Future<bool?> show(
    BuildContext context, {
    required String productId,
    PriceTier? initial,
    Set<int> takenQuantities = const {},
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => TierFormSheet(
        productId: productId,
        initial: initial,
        takenQuantities: takenQuantities,
      ),
    );
  }

  @override
  ConsumerState<TierFormSheet> createState() => _TierFormSheetState();
}

class _TierFormSheetState extends ConsumerState<TierFormSheet> {
  late final TextEditingController _minQuantity;
  late final TextEditingController _unitPrice;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final tier = widget.initial;
    _minQuantity = TextEditingController(
      text: tier?.minQuantity.toString() ?? '',
    );
    _unitPrice = TextEditingController(text: tier?.unitPrice.toString() ?? '');
  }

  @override
  void dispose() {
    _minQuantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final minQuantity = int.tryParse(_minQuantity.text.trim());
    final unitPrice = double.tryParse(_unitPrice.text.trim());
    if (minQuantity == null || minQuantity < 1) {
      setState(() => _error = 'Enter a minimum quantity of 1 or more.');
      return;
    }
    if (unitPrice == null || unitPrice < 0) {
      setState(() => _error = 'Enter a valid unit price.');
      return;
    }
    // A different tier already uses this quantity (unique per product).
    final clashes =
        widget.takenQuantities.contains(minQuantity) &&
        minQuantity != widget.initial?.minQuantity;
    if (clashes) {
      setState(() => _error = 'A tier for $minQuantity+ pieces already exists.');
      return;
    }

    final draft = PriceTierDraft(minQuantity: minQuantity, unitPrice: unitPrice);
    setState(() {
      _submitting = true;
      _error = null;
    });
    final notifier = ref.read(productTiersProvider(widget.productId).notifier);
    final error = _isEditing
        ? await notifier.update(widget.initial!.id, draft)
        : await notifier.create(draft);

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit tier' : 'New tier',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Buyers ordering this many units or more pay the unit price below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _minQuantity,
          labelText: 'Minimum quantity (pieces)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _unitPrice,
          labelText: 'Unit price (each)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: LoadingButton(
            label: _isEditing ? 'Save tier' : 'Add tier',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
