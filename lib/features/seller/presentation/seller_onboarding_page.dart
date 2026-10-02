import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/seller_product_providers.dart' show mySellerProfileIdProvider;

/// "Sell on Pareezay.Hub" — creates the current user's seller store via the existing
/// `createSellerProfile` (profile_id resolved server-side). On success, Seller
/// Studio becomes discoverable.
class SellerOnboardingPage extends ConsumerStatefulWidget {
  const SellerOnboardingPage({super.key});

  @override
  ConsumerState<SellerOnboardingPage> createState() =>
      _SellerOnboardingPageState();
}

class _SellerOnboardingPageState extends ConsumerState<SellerOnboardingPage> {
  final _storeName = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_storeName, _slug, _description, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  String _slugify(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    final storeName = _storeName.text.trim();
    final slug = _slug.text.trim().isEmpty
        ? _slugify(storeName)
        : _slugify(_slug.text);
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
        .createSellerProfile(
          storeName: storeName,
          slug: slug,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(sellerProfileProvider);
    if (state.status == ProfileViewStatus.failure) {
      setState(() {
        _submitting = false;
        _error = state.message ?? 'Could not create your store.';
      });
      return;
    }
    // Make Seller Studio discoverable and open it.
    ref.invalidate(mySellerProfileIdProvider);
    if (!mounted) return;
    LuxurySnackBars.success(context, 'Your store is ready.');
    context.pushReplacement(AppRoutes.sellerDashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Sell on Pareezay.Hub', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Open your store to list jewellery and respond to wholesale '
            'requests.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomTextField(
            controller: _storeName,
            labelText: 'Store name',
            hintText: 'e.g. Zainab Jewellers',
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _slug,
            labelText: 'Store URL (optional — auto from name)',
            hintText: 'zainab-jewellers',
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _city,
            labelText: 'City (optional)',
          ),
          const SizedBox(height: AppSpacing.md),
          MultilineTextField(
            controller: _description,
            labelText: 'About your store (optional)',
            minLines: 3,
            maxLines: 6,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          LoadingButton(
            label: 'Create store',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'New stores start as pending verification. You can list products '
            'right away from Seller Studio.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
