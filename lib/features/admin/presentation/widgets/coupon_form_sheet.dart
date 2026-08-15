import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../orders/presentation/order_formatting.dart';
import '../../domain/entities/admin_coupon.dart';
import '../../providers/admin_coupon_providers.dart';

/// Create/edit form for a coupon. Submits through [adminCouponsProvider];
/// returns `true` when saved. `used_count` is server-managed and not editable.
class CouponFormSheet extends ConsumerStatefulWidget {
  const CouponFormSheet({super.key, this.initial});

  final AdminCoupon? initial;

  static Future<bool?> show(BuildContext context, {AdminCoupon? initial}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => CouponFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<CouponFormSheet> createState() => _CouponFormSheetState();
}

class _CouponFormSheetState extends ConsumerState<CouponFormSheet> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _minOrder;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _usageLimit;
  late final TextEditingController _perUser;
  late String _discountType;
  late String _status;
  DateTime? _startsAt;
  DateTime? _expiresAt;
  bool _submitting = false;
  String? _error;

  static const _statuses = ['draft', 'active', 'paused', 'archived'];

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _code = TextEditingController(text: c?.code ?? '');
    _name = TextEditingController(text: c?.name ?? '');
    _value = TextEditingController(text: c?.discountValue.toString() ?? '');
    _minOrder = TextEditingController(
      text: (c?.minimumOrderAmount ?? 0).toString(),
    );
    _maxDiscount = TextEditingController(
      text: c?.maximumDiscountAmount?.toString() ?? '',
    );
    _usageLimit = TextEditingController(text: c?.usageLimit?.toString() ?? '');
    _perUser = TextEditingController(text: (c?.perUserLimit ?? 1).toString());
    _discountType = c?.discountType ?? 'percentage';
    _status = c?.status ?? 'draft';
    _startsAt = c?.startsAt;
    _expiresAt = c?.expiresAt;
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _value,
      _minOrder,
      _maxDiscount,
      _usageLimit,
      _perUser,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startsAt : _expiresAt) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  String? _validate(double value) {
    if (_code.text.trim().isEmpty) return 'Code is required.';
    if (_name.text.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (value <= 0) return 'Discount value must be greater than 0.';
    if (_discountType == 'percentage' && value > 100) {
      return 'A percentage discount cannot exceed 100.';
    }
    final perUser = int.tryParse(_perUser.text.trim()) ?? 1;
    if (perUser < 1) return 'Per-user limit must be at least 1.';
    final usage = _usageLimit.text.trim().isEmpty
        ? null
        : int.tryParse(_usageLimit.text.trim());
    if (usage != null && usage < 1) return 'Usage limit must be at least 1.';
    if (_startsAt != null &&
        _expiresAt != null &&
        !_expiresAt!.isAfter(_startsAt!)) {
      return 'Expiry must be after the start date.';
    }
    return null;
  }

  Future<void> _submit() async {
    final value = double.tryParse(_value.text.trim()) ?? 0;
    final error = _validate(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(adminCouponsProvider.notifier)
        .save(
          id: widget.initial?.id,
          code: _code.text.trim(),
          name: _name.text.trim(),
          discountType: _discountType,
          discountValue: value,
          minimumOrderAmount: double.tryParse(_minOrder.text.trim()) ?? 0,
          maximumDiscountAmount: _maxDiscount.text.trim().isEmpty
              ? null
              : double.tryParse(_maxDiscount.text.trim()),
          usageLimit: _usageLimit.text.trim().isEmpty
              ? null
              : int.tryParse(_usageLimit.text.trim()),
          perUserLimit: int.tryParse(_perUser.text.trim()) ?? 1,
          startsAt: _startsAt,
          expiresAt: _expiresAt,
          status: _status,
        );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _submitting = false;
        _error = result;
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
          _isEditing ? 'Edit coupon' : 'New coupon',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _code, labelText: 'Code'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _name, labelText: 'Name'),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _discountType,
          decoration: const InputDecoration(labelText: 'Discount type'),
          items: const [
            DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
            DropdownMenuItem(value: 'fixed_amount', child: Text('Fixed amount')),
          ],
          onChanged: (v) => setState(() => _discountType = v ?? _discountType),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _value,
          labelText: _discountType == 'percentage'
              ? 'Discount (%)'
              : 'Discount amount',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _minOrder,
                labelText: 'Min order',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                controller: _maxDiscount,
                labelText: 'Max discount (opt)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _usageLimit,
                labelText: 'Usage limit (opt)',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                controller: _perUser,
                labelText: 'Per-user limit',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DateRow(
          label: 'Starts',
          value: _startsAt,
          onPick: () => _pickDate(true),
          onClear: () => setState(() => _startsAt = null),
        ),
        _DateRow(
          label: 'Expires',
          value: _expiresAt,
          onPick: () => _pickDate(false),
          onClear: () => setState(() => _expiresAt = null),
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == null ? '$label: any' : '$label: ${formatOrderDate(value!)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: onClear,
          ),
        TextButton(onPressed: onPick, child: const Text('Pick')),
      ],
    );
  }
}
