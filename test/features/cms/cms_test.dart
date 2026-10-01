import 'dart:typed_data';

import 'package:aurivo/features/cms/data/cms_repository.dart';
import 'package:aurivo/features/cms/domain/entities/cms_entities.dart';
import 'package:aurivo/features/cms/presentation/cms_page_view.dart';
import 'package:aurivo/features/cms/presentation/help_centre_page.dart';
import 'package:aurivo/features/cms/providers/cms_providers.dart';
import 'package:aurivo/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _faq = CmsPage(
  id: '1',
  slug: 'faq-payment',
  kind: CmsPage.faq,
  title: 'How can I pay?',
  body: 'Cash on delivery at launch.',
);
const _policy = CmsPage(
  id: '2',
  slug: 'returns-policy',
  kind: CmsPage.policy,
  title: 'Returns & refunds',
  body: 'Within 7 days of delivery.',
);

class _FakeCms implements CmsRepository {
  @override
  Future<List<CmsPage>> publishedPages({String? kind}) async =>
      [_faq, _policy].where((p) => kind == null || p.kind == kind).toList();

  @override
  Future<CmsPage?> pageBySlug(String slug) async =>
      [_faq, _policy].where((p) => p.slug == slug).firstOrNull;

  @override
  Future<List<CmsBanner>> liveBanners() async => const [];

  @override
  Future<List<CmsBanner>> allBanners() async => const [];

  @override
  Future<List<CmsPage>> allPages() => publishedPages();

  @override
  Future<void> saveBanner(Map<String, dynamic> values, {String? id}) async {}

  @override
  Future<void> deleteBanner(String id) async {}

  @override
  Future<void> savePage(Map<String, dynamic> values, {String? id}) async {}

  @override
  Future<void> deletePage(String id) async {}

  @override
  Future<String> uploadBannerImage(Uint8List bytes, String extension) async =>
      'banners/x.$extension';
}

void main() {
  testWidgets('help centre lists FAQs (expandable) and opens a policy page', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HelpCentrePage()),
        GoRoute(
          path: '/pages/:slug',
          builder: (_, s) => CmsPageView(slug: s.pathParameters['slug']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cmsRepositoryProvider.overrideWithValue(_FakeCms())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How can I pay?'), findsOneWidget);
    expect(find.text('Cash on delivery at launch.'), findsNothing);
    await tester.tap(find.text('How can I pay?'));
    await tester.pumpAndSettle();
    expect(find.text('Cash on delivery at launch.'), findsOneWidget);

    await tester.tap(find.text('Returns & refunds'));
    await tester.pumpAndSettle();
    expect(find.text('Within 7 days of delivery.'), findsOneWidget);
  });

  testWidgets('admin banners lead the Home carousel and follow their link', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: HomeHeroCarousel(
              products: [],
              banners: [
                CmsBanner(id: 'b1', title: 'Eid Collection', link: '/promo'),
              ],
            ),
          ),
        ),
        GoRoute(path: '/promo', builder: (_, _) => const Text('PROMO')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Eid Collection'), findsOneWidget);
    await tester.tap(find.text('Eid Collection'));
    await tester.pumpAndSettle();
    expect(find.text('PROMO'), findsOneWidget);
  });
}
