import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../../profile/domain/entities/seller_profile.dart';
import '../../profile/providers/profile_providers.dart';

/// Store settings — edits the current user's seller store via the existing
/// `updateSellerProfile`. Ownership (`profile_id`) is resolved server-side;
/// no seller/profile id is ever taken from this UI.
class StoreSettingsPage extends ConsumerStatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  ConsumerState<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends ConsumerState<StoreSettingsPage> {
  final _storeName = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  bool _isWholesaleEnabled = false;
  bool _hydrated = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerProfileProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    for (final c in [_storeName, _slug, _description, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Seeds the controllers from the loaded store once.
  void _hydrate(SellerProfile p) {
    if (_hydrated) return;
    _storeName.text = p.storeName;
    _slug.text = p.slug;
    _description.text = p.description ?? '';
    _city.text = p.city ?? '';
    _isWholesaleEnabled = p.isWholesaleEnabled;
    _hydrated = true;
  }

  String _slugify(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    final storeName = _storeName.text.trim();
    final slug = _slugify(_slug.text);
    if (storeName.length < 2) {
      setState(() => _error = 'Store name must be at least 2 characters.');
      return;
    }
    if (slug.isEmpty) {
      setState(() => _error = 'Please provide a valid store URL (slug).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref
        .read(sellerProfileProvider.notifier)
        .updateSellerProfile(
          storeName: storeName,
          slug: slug,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          isWholesaleEnabled: _isWholesaleEnabled,
        );
    if (!mounted) return;
    final state = ref.read(sellerProfileProvider);
    if (state.status == ProfileViewStatus.failure) {
      setState(() {
        _submitting = false;
        _error = state.message ?? 'Could not save your store.';
      });
      return;
    }
    setState(() => _submitting = false);
    LuxurySnackBars.success(context, 'Store updated.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerProfileProvider);
    final store = state.data;
    if (store != null) _hydrate(store);

    return Scaffold(
      appBar: const LuxuryAppBar(
        title: 'Store settings',
        showBackButton: true,
      ),
      body: switch (state.status) {
        ProfileViewStatus.initial || ProfileViewStatus.loading
            when store == null =>
          const Center(child: LoadingIndicator()),
        ProfileViewStatus.failure when store == null => ErrorStateWidget(
          message: state.message ?? 'Could not load your store.',
          onRetry: () => ref.read(sellerProfileProvider.notifier).load(),
        ),
        _ => store == null
            ? const Center(child: LoadingIndicator())
            : _form(context, store),
      },
    );
  }

  Widget _form(BuildContext context, SellerProfile store) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                store.storeName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            LuxuryBadge(
              label: _statusLabel(store.verificationStatus),
              backgroundColor: store.verificationStatus == 'verified'
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomTextField(controller: _storeName, labelText: 'Store name'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _slug, labelText: 'Store URL (slug)'),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _city, labelText: 'City (optional)'),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _description,
          labelText: 'About your store (optional)',
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wholesale enabled'),
          subtitle: const Text('Accept wholesale (RFQ) requests'),
          value: _isWholesaleEnabled,
          onChanged: (v) => setState(() => _isWholesaleEnabled = v),
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
        LoadingButton(
          label: 'Save changes',
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
    'verified' => 'Verified',
    'rejected' => 'Rejected',
    _ => 'Pending',
  };
}
