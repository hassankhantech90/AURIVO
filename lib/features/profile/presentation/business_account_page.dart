import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/failure.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/business_profile.dart';
import '../providers/profile_providers.dart';

/// Buyer business (B2B) account: register a business to unlock wholesale, and
/// track its verification status. Verification is granted by an administrator —
/// the buyer can never self-verify (enforced by RLS + a DB trigger).
class BusinessAccountPage extends ConsumerStatefulWidget {
  const BusinessAccountPage({super.key});

  @override
  ConsumerState<BusinessAccountPage> createState() =>
      _BusinessAccountPageState();
}

class _BusinessAccountPageState extends ConsumerState<BusinessAccountPage> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _ntn = TextEditingController();
  final _strn = TextEditingController();
  String? _type;
  bool _submitting = false;
  String? _error;

  static const _types = <String>[
    'retailer',
    'wholesaler',
    'manufacturer',
    'exporter',
    'distributor',
    'other',
  ];

  @override
  void dispose() {
    for (final c in [_name, _contact, _phone, _ntn, _strn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final contact = _contact.text.trim();
    final phone = _phone.text.trim();
    if (name.length < 2 || contact.length < 2 || phone.isEmpty) {
      setState(
        () => _error = 'Business name, contact person and phone are required.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .createBusinessProfile(
            businessName: name,
            contactPerson: contact,
            contactPhone: phone,
            businessType: _type,
            ntnNumber: _ntn.text.trim().isEmpty ? null : _ntn.text.trim(),
            strnNumber: _strn.text.trim().isEmpty ? null : _strn.text.trim(),
          );
      ref.invalidate(myBusinessProfileProvider);
      if (!mounted) return;
      LuxurySnackBars.success(
        context,
        'Business submitted — we\'ll review it for verification.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is Failure
            ? error.message
            : 'Could not submit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myBusinessProfileProvider);
    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Business account',
        showBackButton: true,
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load your business account.',
          onRetry: () => ref.invalidate(myBusinessProfileProvider),
        ),
        data: (business) => business != null
            ? _StatusView(business: business)
            : _registrationForm(context),
      ),
    );
  }

  Widget _registrationForm(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Register your business', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Verified businesses unlock wholesale pricing and quote requests.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomTextField(controller: _name, labelText: 'Business name'),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Business type'),
          items: [
            for (final t in _types)
              DropdownMenuItem(value: t, child: Text(_capitalise(t))),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _contact, labelText: 'Contact person'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _phone,
          labelText: 'Contact phone (e.g. 03001234567)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _ntn,
          labelText: 'NTN (optional)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _strn,
          labelText: 'STRN (optional)',
          keyboardType: TextInputType.number,
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
            label: 'Submit for verification',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.business});

  final BusinessProfile business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        LuxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      business.businessName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  _StatusBadge(status: business.verificationStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _row('Type', _label(business.businessType) ?? '—'),
              _row('Contact', business.contactPerson),
              _row('Phone', business.contactPhone),
              if (business.ntnNumber != null) _row('NTN', business.ntnNumber!),
              if (business.strnNumber != null)
                _row('STRN', business.strnNumber!),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(_statusHint(business.verificationStatus),
            style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mediumGrey),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  static String? _label(String? type) =>
      type == null ? null : type[0].toUpperCase() + type.substring(1);

  static String _statusHint(String status) {
    switch (status) {
      case 'verified':
        return 'Your business is verified — wholesale pricing and quote '
            'requests are unlocked.';
      case 'rejected':
        return 'Your business verification was declined. Contact support to '
            'resolve this.';
      case 'suspended':
        return 'Your business account is suspended. Contact support for help.';
      default:
        return 'We\'re reviewing your business. Wholesale unlocks once it\'s '
            'verified.';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'verified' => ('Verified', AppColors.primaryGold, AppColors.jetBlack),
      'rejected' => ('Rejected', AppColors.error, AppColors.pureWhite),
      'suspended' => ('Suspended', AppColors.softGrey, AppColors.charcoal),
      _ => ('Pending', AppColors.porcelain, AppColors.charcoal),
    };
    return LuxuryBadge(label: label, backgroundColor: bg, foregroundColor: fg);
  }
}
