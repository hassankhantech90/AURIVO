import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/brand.dart';
import '../../providers/admin_catalog_providers.dart';
import '../catalog_slug.dart';

/// Create/edit form for a catalog brand.
class BrandFormSheet extends ConsumerStatefulWidget {
  const BrandFormSheet({super.key, this.initial});

  final Brand? initial;

  static Future<bool?> show(BuildContext context, {Brand? initial}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => BrandFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<BrandFormSheet> createState() => _BrandFormSheetState();
}

class _BrandFormSheetState extends ConsumerState<BrandFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late String _status;
  bool _submitting = false;
  String? _error;

  static const _statuses = ['active', 'hidden', 'archived'];

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _name = TextEditingController(text: b?.name ?? '');
    _slug = TextEditingController(text: b?.slug ?? '');
    _description = TextEditingController(text: b?.description ?? '');
    _status = b?.status ?? 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
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
        .read(adminBrandsProvider.notifier)
        .save(
          id: widget.initial?.id,
          name: name,
          slug: slug,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          status: _status,
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
          _isEditing ? 'Edit brand' : 'New brand',
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
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _description,
          labelText: 'Description (optional)',
          minLines: 2,
          maxLines: 4,
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
