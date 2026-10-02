import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/cms_entities.dart';
import '../providers/cms_providers.dart';

/// Help centre: admin-managed FAQs plus links to policy and info pages, and a
/// route to support for anything else.
class HelpCentrePage extends ConsumerWidget {
  const HelpCentrePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final faqs = ref.watch(cmsPagesProvider(CmsPage.faq));
    final policies = ref.watch(cmsPagesProvider(CmsPage.policy));
    final info = ref.watch(cmsPagesProvider(CmsPage.info));

    return Scaffold(
      appBar: LuxuryAppBar(
        title: context.l10n.helpCentre,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cmsPagesProvider(CmsPage.faq));
          ref.invalidate(cmsPagesProvider(CmsPage.policy));
          ref.invalidate(cmsPagesProvider(CmsPage.info));
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Frequently asked questions',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            faqs.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load FAQs.'),
              data: (list) => LuxuryCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final q in list)
                      ExpansionTile(
                        title: Text(q.titleIn(lang)),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.bodyIn(lang),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Policies', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _PageLinks(async: policies),
            const SizedBox(height: AppSpacing.lg),
            _PageLinks(async: info),
            const SizedBox(height: AppSpacing.xl),
            LuxuryCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Still need help?'),
                subtitle: const Text('Contact Pareezay.Hub support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.support),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageLinks extends StatelessWidget {
  const _PageLinks({required this.async});

  final AsyncValue<List<CmsPage>> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : LuxuryCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final p in list)
                    ListTile(
                      title: Text(
                        p.titleIn(Localizations.localeOf(context).languageCode),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.cmsPagePath(p.slug)),
                    ),
                ],
              ),
            ),
    );
  }
}
