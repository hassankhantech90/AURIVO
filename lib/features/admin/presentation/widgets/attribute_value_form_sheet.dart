import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/attribute.dart';
import '../../providers/admin_catalog_providers.dart';

/// Create/edit form for an attribute value (belongs to [attributeId]).
class AttributeValueFormSheet extends ConsumerStatefulWidget {
  const AttributeValueFormSheet({
    super.key,
    required this.attributeId,
    this.initial,
  });

  final String attributeId;
  final AttributeValue? initial;

  static Future<bool?> show(
    BuildContext context, {
    required String attributeId,
    AttributeValue? initial,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) =>
          AttributeValueFormSheet(attributeId: attributeId, initial: initial),
    );
  }

  @override
  ConsumerState<AttributeValueFormSheet> createState() =>
      _AttributeValueFormSheetState();
}

class _AttributeValueFormSheetState
    extends ConsumerState<AttributeValueFormSheet> {
  late final TextEditingController _value;
  late final TextEditingController _sortOrder;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.initial?.value ?? '');
    _sortOrder = TextEditingController(
      text: (widget.initial?.sortOrder ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _value.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Value is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(adminAttributeValuesProvider(widget.attributeId).notifier)
        .save(
          id: widget.initial?.id,
          value: value,
          sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit value' : 'New value',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _value, labelText: 'Value'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _sortOrder,
          labelText: 'Sort order',
          keyboardType: TextInputType.number,
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
            label: 'Save',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
