import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/profile.dart';
import '../../providers/profile_providers.dart';

/// Modal bottom-sheet form to edit the current user's profile details.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final Profile profile;

  static Future<bool?> show(BuildContext context, {required Profile profile}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => EditProfileSheet(profile: profile),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
    _email = TextEditingController(text: widget.profile.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref
        .read(profileProvider.notifier)
        .updateProfile(
          fullName: name,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(profileProvider);
    if (state.status == ProfileViewStatus.failure) {
      setState(() {
        _submitting = false;
        _error = state.message ?? 'Could not update your profile.';
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
        Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _name, labelText: 'Full name'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _phone,
          labelText: 'Phone (optional)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _email,
          labelText: 'Email (optional)',
          keyboardType: TextInputType.emailAddress,
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
