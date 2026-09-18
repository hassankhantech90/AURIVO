import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../authentication/domain/validators/auth_validators.dart';
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
  late final TextEditingController _postal;
  String? _province;
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
    _postal = TextEditingController(text: a?.postalCode ?? '');
    _province = (a?.province != null && kPakistanProvinces.contains(a!.province))
        ? a.province
        : null;
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

  /// Returns a field-specific validation message, or null when the form is
  /// valid. Mirrors the backend CHECK constraints so the buyer gets useful
  /// feedback before a submit ever reaches the database.
  String? _validate({
    required String recipient,
    required String phone,
    required String line1,
    required String city,
  }) {
    if (recipient.isEmpty ||
        phone.isEmpty ||
        line1.isEmpty ||
        city.isEmpty ||
        _province == null) {
      return 'Recipient, phone, address, city and province are required.';
    }
    final phoneError = AuthValidators.pakistanPhone(phone);
    if (phoneError != null) return phoneError;
    if (line1.length < 5) {
      return 'Address line 1 must be at least 5 characters.';
    }
    final postal = _postal.text.trim();
    if (postal.isNotEmpty && !RegExp(r'^[0-9]{5}$').hasMatch(postal)) {
      return 'Postal code must be a 5-digit number.';
    }
    return null;
  }

  Future<void> _submit() async {
    final recipient = _recipient.text.trim();
    final phone = _phone.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    final validationError = _validate(
      recipient: recipient,
      phone: phone,
      line1: line1,
      city: city,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    final province = _province!;

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
    return Padding(
      // Keep the whole form (incl. the submit button) scrollable above the
      // keyboard; the parent sheet is a SingleChildScrollView.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
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
              child: DropdownButtonFormField<String>(
                initialValue: _province,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in kPakistanProvinces)
                    DropdownMenuItem<String>(
                      value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _province = v),
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
      ),
    );
  }
}
