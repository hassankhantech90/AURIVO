import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/address.dart';
import '../../providers/profile_providers.dart';

/// Modal bottom-sheet form to add or edit a shipping address. Submits through
/// [addressesProvider]; returns `true` through the sheet when saved.
class AddressFormSheet extends ConsumerStatefulWidget {
  const AddressFormSheet({super.key, this.initial});

  final Address? initial;

  static Future<bool?> show(BuildContext context, {Address? initial}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => AddressFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  late final TextEditingController _label;
  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _postal;
  bool _isDefault = false;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _label = TextEditingController(text: a?.label ?? '');
    _recipient = TextEditingController(text: a?.recipientName ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _line1 = TextEditingController(text: a?.addressLine1 ?? '');
    _line2 = TextEditingController(text: a?.addressLine2 ?? '');
    _area = TextEditingController(text: a?.area ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _province = TextEditingController(text: a?.province ?? '');
    _postal = TextEditingController(text: a?.postalCode ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _label,
      _recipient,
      _phone,
      _line1,
      _line2,
      _area,
      _city,
      _province,
      _postal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    final recipient = _recipient.text.trim();
    final phone = _phone.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    final province = _province.text.trim();
    if (recipient.isEmpty ||
        phone.isEmpty ||
        line1.isEmpty ||
        city.isEmpty ||
        province.isEmpty) {
      setState(
        () => _error =
            'Recipient, phone, address, city and province are '
            'required.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final notifier = ref.read(addressesProvider.notifier);
    if (_isEditing) {
      await notifier.updateAddress(
        addressId: widget.initial!.id,
        recipientName: recipient,
        phone: phone,
        addressLine1: line1,
        addressLine2: _opt(_line2),
        area: _opt(_area),
        city: city,
        province: province,
        postalCode: _opt(_postal),
        label: _opt(_label),
        isDefault: _isDefault,
      );
    } else {
      await notifier.addAddress(
        recipientName: recipient,
        phone: phone,
        addressLine1: line1,
        addressLine2: _opt(_line2),
        area: _opt(_area),
        city: city,
        province: province,
        postalCode: _opt(_postal),
        label: _opt(_label),
        isDefault: _isDefault,
      );
    }

    if (!mounted) return;
    final state = ref.read(addressesProvider);
    if (state.status == ProfileViewStatus.failure) {
      setState(() {
        _submitting = false;
        _error = state.message ?? 'Could not save the address.';
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
          _isEditing ? 'Edit address' : 'Add address',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _label, labelText: 'Label (e.g. Home)'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _recipient, labelText: 'Recipient name'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _phone,
          labelText: 'Phone',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _line1, labelText: 'Address line 1'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _line2,
          labelText: 'Address line 2 (optional)',
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _area, labelText: 'Area (optional)'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(controller: _city, labelText: 'City'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                controller: _province,
                labelText: 'Province',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _postal,
          labelText: 'Postal code (optional)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Set as default'),
          value: _isDefault,
          onChanged: (v) => setState(() => _isDefault = v),
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
            label: _isEditing ? 'Save address' : 'Add address',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
