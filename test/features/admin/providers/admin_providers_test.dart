import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/core/utils/failure.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_repository.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/profile/domain/entities/business_profile.dart';
import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/seller/domain/entities/seller_product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

SellerProfile _seller(String id) => SellerProfile(
  id: id,
  profileId: 'p-$id',
  storeName: 'Store $id',
  slug: 'store-$id',
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
  _FakeRepo({this.admin = true});
  bool admin;
  int isAdminCalls = 0;

  final List<String> verifications = [];
  final List<String> productStatuses = [];

  @override
  Future<bool> isAdmin() async {
    isAdminCalls++;
    return admin;
  }

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

  final List<String> businessVerifications = [];

  @override
  Future<List<BusinessProfile>> getPendingBusinesses() async =>
      [_business('m'), _business('n')];

  @override
  Future<void> setBusinessVerification({
    required String businessId,
    required String status,
  }) async {
    businessVerifications.add('$businessId:$status');
  }
}

BusinessProfile _business(String id) => BusinessProfile(
  id: id,
  profileId: 'p-$id',
  businessName: 'Biz $id',
  contactPerson: 'Person $id',
  contactPhone: '03001234567',
);

class _ThrowingRepo extends _FakeRepo {
  @override
  Future<void> setSellerVerification({
    required String sellerId,
    required String status,
  }) async {
    throw const Failure(message: 'denied');
  }
}

class _TestSession extends SessionNotifier {
  _TestSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      );
  void set(SessionState next) => state = next;
}

SessionState _authAs(String userId) => SessionState(
  status: SessionStatus.authenticated,
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
  ),
);

const SessionState _guest = SessionState(status: SessionStatus.unauthenticated);

ProviderContainer _container(AdminRepository repo) {
  final container = ProviderContainer(
    overrides: [adminRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Container that also drives the auth session, for the admin-gate tests.
ProviderContainer _containerWithSession(
  AdminRepository repo,
  _TestSession session,
) {
  final container = ProviderContainer(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      sessionProvider.overrideWith((ref) => session),
    ],
  );
  addTearDown(container.dispose);
  // Keep the async gate alive so it rebuilds on session changes.
  container.listen(isAdminProvider, (_, _) {});
  return container;
}

void main() {
  group('isAdminProvider gate', () {
    test('is false when signed out, without hitting the RPC', () async {
      final repo = _FakeRepo(admin: true);
      final session = _TestSession()..set(_guest);
      final container = _containerWithSession(repo, session);

      expect(await container.read(isAdminProvider.future), isFalse);
      expect(repo.isAdminCalls, 0); // short-circuited: no has_role RPC
    });

    test('reflects the current signed-in user', () async {
      final repo = _FakeRepo(admin: true);
      final session = _TestSession()..set(_authAs('admin-user'));
      final container = _containerWithSession(repo, session);

      expect(await container.read(isAdminProvider.future), isTrue);
    });

    test('recomputes on account switch (no stale admin leak)', () async {
      final repo = _FakeRepo(admin: true); // signed-in admin
      final session = _TestSession()..set(_authAs('admin-user'));
      final container = _containerWithSession(repo, session);

      expect(await container.read(isAdminProvider.future), isTrue);

      // Switch to a different (non-admin) identity: must recompute to false,
      // never reuse the cached admin=true.
      repo.admin = false;
      session.set(_authAs('buyer-user'));

      expect(await container.read(isAdminProvider.future), isFalse);
    });
  });

  test('pendingSellers load then approve removes from the queue', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(pendingSellersProvider.notifier);
    await notifier.load();
    expect(
      container.read(pendingSellersProvider).data.map((s) => s.id),
      ['a', 'b'],
    );

    final err = await notifier.setVerification('a', 'verified');
    expect(err, isNull);
    expect(repo.verifications, ['a:verified']);
    expect(container.read(pendingSellersProvider).data.map((s) => s.id), ['b']);
  });

  test('pendingBusinesses load then approve removes from the queue', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(pendingBusinessesProvider.notifier);
    await notifier.load();
    expect(
      container.read(pendingBusinessesProvider).data.map((b) => b.id),
      ['m', 'n'],
    );

    final err = await notifier.setVerification('m', 'verified');
    expect(err, isNull);
    expect(repo.businessVerifications, ['m:verified']);
    expect(
      container.read(pendingBusinessesProvider).data.map((b) => b.id),
      ['n'],
    );
  });

  test('pendingProducts load then reject removes from the queue', () async {
    final repo = _FakeRepo();
    final container = _container(repo);
    final notifier = container.read(pendingProductsProvider.notifier);
    await notifier.load();
    expect(container.read(pendingProductsProvider).data, hasLength(2));

    final err = await notifier.setStatus('x', 'rejected');
    expect(err, isNull);
    expect(repo.productStatuses, ['x:rejected']);
    expect(container.read(pendingProductsProvider).data.map((p) => p.id), ['y']);
  });

  test('setVerification surfaces an error message on failure', () async {
    final repo = _ThrowingRepo();
    final container = _container(repo);
    await container.read(pendingSellersProvider.notifier).load();
    final err = await container
        .read(pendingSellersProvider.notifier)
        .setVerification('a', 'verified');
    expect(err, contains('denied'));
  });
}
