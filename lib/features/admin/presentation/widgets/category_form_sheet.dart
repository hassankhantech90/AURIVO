import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../categories/domain/entities/category.dart';
import '../../providers/admin_catalog_providers.dart';
import '../catalog_slug.dart';

/// Create/edit form for a catalog category. Submits through
/// [adminCategoriesProvider]; returns `true` when saved.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, this.initial, this.categories = const []});

  final Category? initial;
  final List<Category> categories;

  static Future<bool?> show(
    BuildContext context, {
    Category? initial,
    List<Category> categories = const [],
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) =>
          CategoryFormSheet(initial: initial, categories: categories),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _sortOrder;
  String? _parentId;
  late bool _isActive;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _slug = TextEditingController(text: c?.slug ?? '');
    _sortOrder = TextEditingController(text: (c?.sortOrder ?? 0).toString());
    _parentId = c?.parentId;
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _sortOrder.dispose();
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
        .read(adminCategoriesProvider.notifier)
        .save(
          id: widget.initial?.id,
          name: name,
          slug: slug,
          parentId: _parentId,
          sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          isActive: _isActive,
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
    // A category cannot be its own parent.
    final parents = widget.categories
        .where((c) => c.id != widget.initial?.id)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit category' : 'New category',
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
        DropdownButtonFormField<String?>(
          initialValue: _parentId,
          decoration: const InputDecoration(labelText: 'Parent (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None (top level)')),
            for (final c in parents)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _parentId = v),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _sortOrder,
          labelText: 'Sort order',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
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
