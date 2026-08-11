import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../providers/rfq_providers.dart';

/// Modal bottom-sheet form for creating a request for quotation.
///
/// Presented via [LuxuryBottomSheet]; there is no dedicated route. Product /
/// variant / seller context is passed in and never shown as editable ids — the
/// buyer only enters quantity and optional target price / message. The buyer
/// identity is resolved server-side, never from this form. Returns `true`
/// through the sheet when an RFQ was created.
class RfqFormSheet extends ConsumerStatefulWidget {
  const RfqFormSheet({
    super.key,
    this.productId,
    this.productVariantId,
    this.sellerProfileId,
    this.contextLabel,
  });

  final String? productId;
  final String? productVariantId;
  final String? sellerProfileId;

  /// Optional human label describing what the request is about (e.g. a product
  /// title) shown at the top of the form.
  final String? contextLabel;

  static Future<bool?> show(
    BuildContext context, {
    String? productId,
    String? productVariantId,
    String? sellerProfileId,
    String? contextLabel,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => RfqFormSheet(
        productId: productId,
        productVariantId: productVariantId,
        sellerProfileId: sellerProfileId,
        contextLabel: contextLabel,
      ),
    );
  }

  @override
  ConsumerState<RfqFormSheet> createState() => _RfqFormSheetState();
}

class _RfqFormSheetState extends ConsumerState<RfqFormSheet> {
  final _quantityController = TextEditingController();
  final _targetPriceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _targetPriceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1) {
      setState(() => _error = 'Please enter a quantity of at least 1.');
      return;
    }
    final targetPrice = _targetPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_targetPriceController.text.trim());

    setState(() {
      _submitting = true;
      _error = null;
    });

    final message = await ref
        .read(myRfqsProvider.notifier)
        .create(
          quantity: quantity,
          productId: widget.productId,
          productVariantId: widget.productVariantId,
          sellerProfileId: widget.sellerProfileId,
          targetPrice: targetPrice,
          message: _messageController.text,
        );

    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Request a quote', style: theme.textTheme.titleLarge),
        if (widget.contextLabel != null && widget.contextLabel!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.contextLabel!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _quantityController,
          labelText: 'Quantity',
          hintText: 'e.g. 100',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _targetPriceController,
          labelText: 'Target price per unit (optional)',
          hintText: 'e.g. 950',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _messageController,
          labelText: 'Message (optional)',
          hintText: 'Describe your requirement, timeline, customisation…',
          minLines: 3,
          maxLines: 6,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: LoadingButton(
            label: 'Send request',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
