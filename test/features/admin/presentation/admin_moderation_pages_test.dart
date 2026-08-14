import 'package:aurivo/features/admin/domain/repositories/admin_repository.dart';
import 'package:aurivo/features/admin/presentation/admin_products_page.dart';
import 'package:aurivo/features/admin/presentation/admin_verifications_page.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_product.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _seller(String id) => SellerProfile(
  id: id,
  profileId: 'p-$id',
  storeName: 'Store $id',
  slug: 'store-$id',
  city: 'Lahore',
  verificationStatus: 'pending',
);

SellerProduct _product(String id) => SellerProduct.fromMap({
  'id': id,
  'seller_id': 'sp1',
  'title': 'Ring $id',
  'slug': 'ring-$id',
  'jewellery_type': 'ring',
  'currency': 'PKR',
  'base_price': 1000,
  'status': 'pending',
});

class _FakeRepo implements AdminRepository {
  final List<String> verifications = [];
  final List<String> productStatuses = [];

  @override
  Future<bool> isAdmin() async => true;

  @override
  Future<List<SellerProfile>> getPendingSellers() async =>
      [_seller('a'), _seller('b')];

  @override
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  }) async {
    verifications.add('$sellerId:$status');
  }

  @override
  Future<List<SellerProduct>> getPendingProducts() async =>
      [_product('x'), _product('y')];

  @override
  Future<void> setProductStatus({
    required String productId,
    required String status,
  }) async {
    productStatuses.add('$productId:$status');
  }
}

Widget _wrap(AdminRepository repo, Widget page) => ProviderScope(
  overrides: [adminRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: page),
);

void main() {
  testWidgets('verification queue lists stores and verifies one', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo, const AdminVerificationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Store a'), findsOneWidget);
    expect(find.text('Store b'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Verify').first);
    await tester.pumpAndSettle();

    expect(repo.verifications, ['a:verified']);
    expect(find.text('Store a'), findsNothing); // dropped from the queue
  });

  testWidgets('product queue lists products and approves one', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo, const AdminProductsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Ring x'), findsOneWidget);
    expect(find.text('Ring y'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Approve').first);
    await tester.pumpAndSettle();

    expect(repo.productStatuses, ['x:approved']);
    expect(find.text('Ring x'), findsNothing);
  });
}
