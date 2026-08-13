import 'package:aurivo/features/profile/domain/entities/seller_profile.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SellerProfile _sampleStore({
  String storeName = 'Zainab Jewellers',
  String slug = 'zainab-jewellers',
  bool wholesale = false,
}) => SellerProfile(
  id: 'sp1',
  profileId: 'p1',
  storeName: storeName,
  slug: slug,
  isWholesaleEnabled: wholesale,
);

/// In-memory ProfileRepository covering only the seller-profile surface.
/// It never accepts a profile/seller id from the caller — mirroring the real
/// server-side ownership resolution.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({SellerProfile? initial}) : _store = initial;
  SellerProfile? _store;

  int createCalls = 0;
  int updateCalls = 0;
  Map<String, dynamic>? lastCreateArgs;
  Map<String, dynamic>? lastUpdateArgs;

  @override
  Future<SellerProfile?> getSellerProfile() async => _store;

  @override
  Future<SellerProfile> createSellerProfile({
    required String storeName,
    required String slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    createCalls++;
    lastCreateArgs = {
      'storeName': storeName,
      'slug': slug,
      'description': description,
      'city': city,
    };
    _store = SellerProfile(
      id: 'sp1',
      profileId: 'p1',
      storeName: storeName,
      slug: slug,
      description: description,
      city: city,
    );
    return _store!;
  }

  @override
  Future<SellerProfile> updateSellerProfile({
    String? storeName,
    String? slug,
    String? description,
    String? city,
    String? logoUrl,
    String? bannerUrl,
    bool? isWholesaleEnabled,
  }) async {
    updateCalls++;
    lastUpdateArgs = {
      'storeName': storeName,
      'slug': slug,
      'description': description,
      'city': city,
      'isWholesaleEnabled': isWholesaleEnabled,
    };
    final current = _store ?? _sampleStore();
    _store = SellerProfile(
      id: current.id,
      profileId: current.profileId,
      storeName: storeName ?? current.storeName,
      slug: slug ?? current.slug,
      description: description ?? current.description,
      city: city ?? current.city,
      isWholesaleEnabled: isWholesaleEnabled ?? current.isWholesaleEnabled,
    );
    return _store!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(ProfileRepository repo) {
  final container = ProviderContainer(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load surfaces "no seller profile yet" as a failure state', () async {
    final container = _container(_FakeProfileRepository());
    await container.read(sellerProfileProvider.notifier).load();
    final state = container.read(sellerProfileProvider);
    expect(state.status, ProfileViewStatus.failure);
    expect(state.data, isNull);
  });

  test('load exposes an existing store', () async {
    final container = _container(_FakeProfileRepository(initial: _sampleStore()));
    await container.read(sellerProfileProvider.notifier).load();
    final state = container.read(sellerProfileProvider);
    expect(state.status, ProfileViewStatus.success);
    expect(state.data!.storeName, 'Zainab Jewellers');
  });

  test('createSellerProfile succeeds and never forwards an id', () async {
    final repo = _FakeProfileRepository();
    final container = _container(repo);
    await container
        .read(sellerProfileProvider.notifier)
        .createSellerProfile(
          storeName: 'Aurum Studio',
          slug: 'aurum-studio',
          city: 'Lahore',
        );
    expect(repo.createCalls, 1);
    expect(repo.lastCreateArgs!.containsKey('profileId'), isFalse);
    expect(repo.lastCreateArgs!['slug'], 'aurum-studio');
    final state = container.read(sellerProfileProvider);
    expect(state.status, ProfileViewStatus.success);
    expect(state.data!.storeName, 'Aurum Studio');
  });

  test('updateSellerProfile forwards only the exposed fields', () async {
    final repo = _FakeProfileRepository(initial: _sampleStore());
    final container = _container(repo);
    await container.read(sellerProfileProvider.notifier).load();

    await container
        .read(sellerProfileProvider.notifier)
        .updateSellerProfile(
          storeName: 'Zainab Fine Jewellery',
          slug: 'zainab-fine',
          isWholesaleEnabled: true,
        );
    expect(repo.updateCalls, 1);
    expect(repo.lastUpdateArgs!['isWholesaleEnabled'], isTrue);
    expect(repo.lastUpdateArgs!.containsKey('verificationStatus'), isFalse);
    final state = container.read(sellerProfileProvider);
    expect(state.data!.storeName, 'Zainab Fine Jewellery');
    expect(state.data!.isWholesaleEnabled, isTrue);
  });
}
