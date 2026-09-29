import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/rfq_providers.dart';
import 'wholesale_access.dart';
import 'widgets/rfq_card.dart';
import 'widgets/rfq_form_sheet.dart';

/// Wholesale hub: the buyer's request-for-quotation list, plus a standalone
/// "New request" entry. Quote requests are buyer-owned; guests are directed to
/// login before creating or listing them.
class WholesalePage extends ConsumerStatefulWidget {
  const WholesalePage({super.key});

  @override
  ConsumerState<WholesalePage> createState() => _WholesalePageState();
}

class _WholesalePageState extends ConsumerState<WholesalePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) {
        ref.read(myRfqsProvider.notifier).load();
      }
    });
  }

  Future<void> _load() => ref.read(myRfqsProvider.notifier).load();

  Future<void> _newRequest() async {
    if (!await ensureVerifiedBusiness(context, ref)) return;
    if (!mounted) return;
    final saved = await RfqFormSheet.show(context);
    if (saved == true && mounted) {
      // The form creates through myRfqsProvider, which reloads the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Wholesale'),
        body: EmptyStateWidget(
          title: 'Request wholesale quotes',
          message:
              'Sign in to send quote requests to sellers and track replies.',
          icon: Icons.request_quote_outlined,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final state = ref.watch(myRfqsProvider);
    final rfqs = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Wholesale'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: Column(
        children: [
          const _BusinessVerificationBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: switch (state.status) {
                RfqViewStatus.initial || RfqViewStatus.loading
                    when state.data == null =>
                  const Center(child: LoadingIndicator()),
          RfqViewStatus.failure when state.data == null => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorStateWidget(
                message: state.message ?? 'Could not load your requests.',
                onRetry: _load,
              ),
            ],
          ),
          _ =>
            rfqs.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'No quote requests yet',
                        message:
                            'Tap "New request" to ask sellers for a quote.',
                        icon: Icons.request_quote_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: rfqs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final rfq = rfqs[index];
                      return RfqCard(
                        rfq: rfq,
                        onTap: () =>
                            context.push(AppRoutes.rfqDetailPath(rfq.id)),
                      );
                    },
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompts the buyer to register/verify a business for wholesale. Hidden once
/// the business is verified.
class _BusinessVerificationBanner extends ConsumerWidget {
  const _BusinessVerificationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBusinessProfileProvider);
    final business = async.valueOrNull;
    if (async.isLoading || business?.verificationStatus == 'verified') {
      return const SizedBox.shrink();
    }
    final (message, cta) = switch (business?.verificationStatus) {
      'pending' => ('Your business is under review for wholesale access.', 'View status'),
      'rejected' => ('Business verification was declined. Tap for details.', 'View status'),
      _ => ('Register your business to unlock wholesale pricing & quotes.', 'Get verified'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: LuxuryCard(
        onTap: () => context.push(AppRoutes.businessAccount),
        child: Row(
          children: [
            const Icon(
              Icons.business_center_outlined,
              color: AppColors.primaryGold,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              cta,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.deepGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
