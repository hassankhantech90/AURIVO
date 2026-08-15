import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/entities/admin_coupon.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_coupon_repository.dart';
import 'package:aurivo/features/admin/providers/admin_coupon_providers.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart'
    show AdminStatus;
import 'package:aurivo/features/coupons/domain/entities/coupon_redemption.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminCoupon _coupon(String id, {String status = 'active'}) => AdminCoupon(
  id: id,
  code: 'C$id',
  name: 'Coupon $id',
  discountType: 'percentage',
  discountValue: 10,
  status: status,
);

class _FakeRepo implements AdminCouponRepository {
  List<AdminCoupon> coupons = [_coupon('1')];
  final List<String> log = [];

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
    log.add('create:$code');
    coupons = [...coupons, _coupon('2')];
    return coupons.last;
  }

  @override
  Future<void> setStatus({required String id, required String status}) async {
    log.add('status:$id:$status');
    coupons = coupons
        .map((c) => c.id == id ? _coupon(id, status: status) : c)
        .toList();
  }

  @override
  Future<void> deleteCoupon(String id) async {
    log.add('delete:$id');
    coupons = coupons.where((c) => c.id != id).toList();
  }

  @override
  Future<List<CouponRedemption>> listRedemptions(String couponId) async => [
    CouponRedemption(
      id: 'r1',
      couponId: couponId,
      profileId: 'p1',
      discountAmount: 50,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(AdminCouponRepository repo) {
  final container = ProviderContainer(
    overrides: [adminCouponRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load then create reloads the list', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(adminCouponsProvider.notifier);
    await notifier.load();
    expect(container.read(adminCouponsProvider).status, AdminStatus.success);

    final err = await notifier.save(
      code: 'SAVE20',
      name: 'Save 20',
      discountType: 'percentage',
      discountValue: 20,
      minimumOrderAmount: 0,
      perUserLimit: 1,
      status: 'active',
    );
    expect(err, isNull);
    expect(repo.log, contains('create:SAVE20'));
    expect(container.read(adminCouponsProvider).data, hasLength(2));
  });

  test('setStatus toggles then reloads', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(adminCouponsProvider.notifier);
    await notifier.load();
    final err = await notifier.setStatus('1', 'paused');
    expect(err, isNull);
    expect(repo.log, contains('status:1:paused'));
    expect(container.read(adminCouponsProvider).data.single.status, 'paused');
  });

  test('remove soft-deletes then reloads', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(adminCouponsProvider.notifier);
    await notifier.load();
    await notifier.remove('1');
    expect(repo.log, contains('delete:1'));
    expect(container.read(adminCouponsProvider).data, isEmpty);
  });

  test('redemptions provider returns records', () async {
    final container = _container(_FakeRepo());
    final reds = await container.read(
      adminCouponRedemptionsProvider('1').future,
    );
    expect(reds.single.discountAmount, 50);
  });

  test('save surfaces error message on failure', () async {
    final container = _container(_ThrowingRepo());
    final err = await container.read(adminCouponsProvider.notifier).save(
      code: 'X',
      name: 'x',
      discountType: 'percentage',
      discountValue: 10,
      minimumOrderAmount: 0,
      perUserLimit: 1,
      status: 'active',
    );
    expect(err, contains('unique'));
  });
}

class _ThrowingRepo extends _FakeRepo {
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
  }) async => throw const Failure(message: 'code must be unique');
}
