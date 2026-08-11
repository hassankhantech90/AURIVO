import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/seller_variant.dart';
import '../../providers/seller_variant_providers.dart';

/// Modal bottom-sheet form to create or edit a product variant. Presented via
/// [LuxuryBottomSheet]; submits through [productVariantsProvider]. Returns
/// `true` through the sheet when a variant was saved.
class VariantFormSheet extends ConsumerStatefulWidget {
  const VariantFormSheet({super.key, required this.productId, this.initial});

  final String productId;
  final SellerVariant? initial;

  static Future<bool?> show(
    BuildContext context, {
    required String productId,
    SellerVariant? initial,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => VariantFormSheet(productId: productId, initial: initial),
    );
  }

  @override
  ConsumerState<VariantFormSheet> createState() => _VariantFormSheetState();
}

class _VariantFormSheetState extends ConsumerState<VariantFormSheet> {
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _comparePrice;
  late final TextEditingController _weight;
  late final TextEditingController _stock;
  late final TextEditingController _lowStock;
  late final TextEditingController _barcode;
  String _currency = 'PKR';
  bool _active = true;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _sku = TextEditingController(text: v?.sku ?? '');
    _price = TextEditingController(text: v?.price.toString() ?? '');
    _comparePrice = TextEditingController(
      text: v?.comparePrice?.toString() ?? '',
    );
    _weight = TextEditingController(text: v?.weightGrams?.toString() ?? '');
    _stock = TextEditingController(text: v?.stockQuantity.toString() ?? '0');
    _lowStock = TextEditingController(
      text: v?.lowStockThreshold.toString() ?? '0',
    );
    _barcode = TextEditingController(text: v?.barcode ?? '');
    _currency = v?.currency ?? 'PKR';
    _active = v?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _sku,
      _price,
      _comparePrice,
      _weight,
      _stock,
      _lowStock,
      _barcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final sku = _sku.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (sku.isEmpty || price == null || price < 0) {
      setState(() => _error = 'A SKU and a valid price are required.');
      return;
    }
    final draft = VariantDraft(
      sku: sku,
      price: price,
      currency: _currency,
      comparePrice: double.tryParse(_comparePrice.text.trim()),
      weightGrams: double.tryParse(_weight.text.trim()),
      barcode: _barcode.text,
      stockQuantity: int.tryParse(_stock.text.trim()) ?? 0,
      lowStockThreshold: int.tryParse(_lowStock.text.trim()) ?? 0,
      isActive: _active,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    final notifier = ref.read(
      productVariantsProvider(widget.productId).notifier,
    );
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
          _isEditing ? 'Edit variant' : 'New variant',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _sku, labelText: 'SKU'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _price,
                labelText: 'Price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'PKR'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _stock,
                labelText: 'Stock',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                controller: _lowStock,
                labelText: 'Low-stock alert',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _weight,
          labelText: 'Weight (grams, optional)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _comparePrice,
          labelText: 'Compare-at price (optional)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _barcode, labelText: 'Barcode (optional)'),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active (sellable)'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
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
            label: _isEditing ? 'Save variant' : 'Add variant',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
