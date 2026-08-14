import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/attribute.dart';
import '../../providers/admin_catalog_providers.dart';
import '../catalog_slug.dart';

/// Create/edit form for a catalog attribute definition.
class AttributeFormSheet extends ConsumerStatefulWidget {
  const AttributeFormSheet({super.key, this.initial});

  final Attribute? initial;

  static Future<bool?> show(BuildContext context, {Attribute? initial}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => AttributeFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AttributeFormSheet> createState() => _AttributeFormSheetState();
}

class _AttributeFormSheetState extends ConsumerState<AttributeFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _unit;
  late String _dataType;
  late bool _isFilterable;
  bool _submitting = false;
  String? _error;

  static const _dataTypes = ['text', 'number', 'boolean', 'date'];

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _name = TextEditingController(text: a?.name ?? '');
    _slug = TextEditingController(text: a?.slug ?? '');
    _unit = TextEditingController(text: a?.unit ?? '');
    _dataType = a?.dataType ?? 'text';
    _isFilterable = a?.isFilterable ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final slug = _slug.text.trim().isEmpty ? slugify(name) : slugify(_slug.text);
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }
    if (slug.isEmpty) {
      setState(() => _error = 'Please provide a valid slug.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(adminAttributesProvider.notifier)
        .save(
          id: widget.initial?.id,
          name: name,
          slug: slug,
          dataType: _dataType,
          unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
          isFilterable: _isFilterable,
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
          _isEditing ? 'Edit attribute' : 'New attribute',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _name, labelText: 'Name'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _slug,
          labelText: 'Slug (optional — auto from name)',
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _dataType,
          decoration: const InputDecoration(labelText: 'Data type'),
          items: _dataTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _dataType = v ?? _dataType),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _unit,
          labelText: 'Unit (optional — e.g. g, mm)',
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Filterable'),
          subtitle: const Text('Show as a buyer catalogue filter'),
          value: _isFilterable,
          onChanged: (v) => setState(() => _isFilterable = v),
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
