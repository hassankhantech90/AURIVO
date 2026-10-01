import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../providers/cms_providers.dart';

/// Renders a published policy / info page by slug (plain text, paragraphs
/// separated by blank lines).
class CmsPageView extends ConsumerWidget {
  const CmsPageView({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsPageProvider(slug));
    final title = async.valueOrNull?.title ?? '';
    return Scaffold(
      appBar: LuxuryAppBar(title: title, showBackButton: true),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load this page.',
          onRetry: () => ref.invalidate(cmsPageProvider(slug)),
        ),
        data: (page) => page == null
            ? const EmptyStateWidget(
                title: 'Page not found',
                message: 'This page is not available.',
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  SelectableText(
                    page.body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),
      ),
    );
  }
}
