import 'package:aurivo/features/products/domain/entities/product.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/repositories/seller_repository.dart';
import 'package:aurivo/features/seller/presentation/seller_page.dart';
import 'package:aurivo/features/seller/providers/seller_providers.dart';
import 'package:aurivo/shared/widgets/cards/seller_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

SellerProfile _seller({
  String slug = 'gold-house',
  String name = 'Gold House',
}) => SellerProfile(
  id: 's-$slug',
  profileId: 'p1',
  storeName: name,
  slug: slug,
  verificationStatus: 'verified',
);

class _FakeSellerRepository implements SellerRepository {
  _FakeSellerRepository(this.sellers);
  final List<SellerProfile> sellers;

  @override
  Future<List<SellerProfile>> getVerifiedSellers({
    int limit = 20,
    int offset = 0,
  }) async => sellers;

  @override
  Future<SellerProfile?> getSellerBySlug(String slug) async => null;

  @override
  Future<SellerProfile?> getSellerById(String id) async => null;

  @override
  Future<List<Product>> getSellerProducts(
    String sellerId, {
    int limit = 20,
    int offset = 0,
  }) async => const [];
}

Widget _wrap(SellerRepository repo) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SellerPage())],
  );
  return ProviderScope(
    overrides: [sellerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('directory renders verified seller cards', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeSellerRepository([
          _seller(name: 'Gold House'),
          _seller(slug: 'silver', name: 'Silver Line'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SellerCard), findsNWidgets(2));
    expect(find.text('Gold House'), findsOneWidget);
    expect(find.text('Silver Line'), findsOneWidget);
  });

  testWidgets('directory shows an empty state when there are no sellers', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeSellerRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No sellers yet'), findsOneWidget);
  });
}
