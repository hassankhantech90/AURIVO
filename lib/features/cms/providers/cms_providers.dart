import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../data/cms_repository.dart';
import '../domain/entities/cms_entities.dart';

final cmsRepositoryProvider = Provider<CmsRepository>((ref) {
  const service = SupabaseService();
  return const SupabaseCmsRepository(
    database: SupabaseDatabaseService(supabaseService: service),
    storage: SupabaseStorageService(supabaseService: service),
  );
});

/// Live Home banners (active, within schedule). Empty on error so Home never
/// breaks because of CMS content.
final homeBannersProvider = FutureProvider.autoDispose<List<CmsBanner>>((
  ref,
) async {
  try {
    return await ref.watch(cmsRepositoryProvider).liveBanners();
  } catch (_) {
    return const [];
  }
});

/// Published pages of a kind ('faq', 'policy', 'info').
final cmsPagesProvider = FutureProvider.autoDispose
    .family<List<CmsPage>, String>(
      (ref, kind) =>
          ref.watch(cmsRepositoryProvider).publishedPages(kind: kind),
    );

final cmsPageProvider = FutureProvider.autoDispose.family<CmsPage?, String>(
  (ref, slug) => ref.watch(cmsRepositoryProvider).pageBySlug(slug),
);

/// Admin lists (RLS returns every row to admins).
final adminBannersProvider = FutureProvider.autoDispose<List<CmsBanner>>(
  (ref) => ref.watch(cmsRepositoryProvider).allBanners(),
);

final adminPagesProvider = FutureProvider.autoDispose<List<CmsPage>>(
  (ref) => ref.watch(cmsRepositoryProvider).allPages(),
);
