import 'package:aurivo/features/admin/domain/entities/admin_coupon.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_coupon_repository.dart';
import 'package:aurivo/features/admin/presentation/admin_coupons_page.dart';
import 'package:aurivo/features/admin/providers/admin_coupon_providers.dart';
import 'package:aurivo/features/coupons/domain/entities/coupon_redemption.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminCoupon _coupon(String id, {String status = 'active', int used = 3}) =>
    AdminCoupon(
      id: id,
      code: 'SAVE$id',
      name: 'Save $id',
      discountType: 'percentage',
      discountValue: 10,
      usageLimit: 100,
      usedCount: used,
      status: status,
    );

class _FakeRepo implements AdminCouponRepository {
  List<AdminCoupon> coupons = [_coupon('1'), _coupon('2', status: 'paused')];
  int createdCount = 0;

  @override
  Future<List<AdminCoupon>> listCoupons() async => coupons;

  @override
  Future<AdminCoupon> createCoupon({
    required String code,
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    double minimumOrderAmount = 0,
    double? maximumDiscountAmount,
    int? usageLimit,
    int perUserLimit = 1,
    DateTime? startsAt,
    DateTime? expiresAt,
    String status = 'draft',
  }) async {
    createdCount++;
    coupons = [...coupons, _coupon('3')];
    return coupons.last;
  }

  @override
  Future<List<CouponRedemption>> listRedemptions(String couponId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(AdminCouponRepository repo) => ProviderScope(
  overrides: [adminCouponRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: AdminCouponsPage()),
);

void main() {
  testWidgets('lists coupons with discount, usage and status', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pumpAndSettle();
    expect(find.text('SAVE1'), findsOneWidget);
    expect(find.text('SAVE2'), findsOneWidget);
    expect(find.textContaining('10% off · 3/100 used'), findsNWidgets(2));
    expect(find.text('active'), findsOneWidget);
    expect(find.text('paused'), findsOneWidget);
  });

  testWidgets('new coupon form validates a percentage over 100', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New coupon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'BIG'); // code
    await tester.enterText(find.byType(TextField).at(1), 'Big Sale'); // name
    await tester.enterText(find.byType(TextField).at(2), '150'); // % value
    await tester.tap(find.widgetWithText(LoadingButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.createdCount, 0);
    expect(find.textContaining('cannot exceed 100'), findsOneWidget);
  });
}
