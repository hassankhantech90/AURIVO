import 'package:aurivo/features/profile/domain/entities/address.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Address _address({String id = 'a1', bool isDefault = false}) => Address(
  id: id,
  profileId: 'p1',
  addressType: 'shipping',
  recipientName: 'Aiman',
  phone: '03000000000',
  addressLine1: '1 Mall Road',
  city: 'Lahore',
  province: 'Punjab',
  isDefault: isDefault,
);

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({List<Address> addresses = const []})
    : _addresses = [...addresses];
  List<Address> _addresses;

  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int setDefaultCalls = 0;

  @override
  Future<List<Address>> getAddresses() async => List.unmodifiable(_addresses);

  @override
  Future<Address> addAddress({
    required String recipientName,
    required String phone,
    required String addressLine1,
    required String city,
    required String province,
    String addressType = 'shipping',
    String? label,
    String? addressLine2,
    String? area,
    String? postalCode,
    String country = 'Pakistan',
    bool isDefault = false,
  }) async {
    addCalls++;
    final a = _address(id: 'a${_addresses.length + 1}', isDefault: isDefault);
    _addresses = [..._addresses, a];
    return a;
  }

  @override
  Future<Address> updateAddress({
    required String addressId,
    String? recipientName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? area,
    String? city,
    String? province,
    String? postalCode,
    String? label,
    String? addressType,
    bool? isDefault,
  }) async {
    updateCalls++;
    return _address(id: addressId);
  }

  @override
  Future<void> deleteAddress({required String addressId}) async {
    deleteCalls++;
    _addresses = _addresses.where((a) => a.id != addressId).toList();
  }

  @override
  Future<Address> setDefaultAddress({required String addressId}) async {
    setDefaultCalls++;
    _addresses = _addresses
        .map((a) => _address(id: a.id, isDefault: a.id == addressId))
        .toList();
    return _address(id: addressId, isDefault: true);
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
  test('load exposes the addresses', () async {
    final container = _container(
      _FakeProfileRepository(addresses: [_address()]),
    );
    await container.read(addressesProvider.notifier).load();
    final state = container.read(addressesProvider);
    expect(state.status, ProfileViewStatus.success);
    expect(state.data!.single.id, 'a1');
  });

  test('addAddress refreshes the list', () async {
    final repo = _FakeProfileRepository();
    final container = _container(repo);
    await container
        .read(addressesProvider.notifier)
        .addAddress(
          recipientName: 'A',
          phone: '0300',
          addressLine1: '1 St',
          city: 'Lahore',
          province: 'Punjab',
        );
    expect(repo.addCalls, 1);
    expect(container.read(addressesProvider).data, isNotEmpty);
  });

  test('setDefault and delete refresh the list', () async {
    final repo = _FakeProfileRepository(
      addresses: [
        _address(id: 'a1'),
        _address(id: 'a2'),
      ],
    );
    final container = _container(repo);
    final notifier = container.read(addressesProvider.notifier);
    await notifier.load();

    await notifier.setDefaultAddress('a2');
    expect(repo.setDefaultCalls, 1);
    expect(
      container
          .read(addressesProvider)
          .data!
          .firstWhere((a) => a.id == 'a2')
          .isDefault,
      isTrue,
    );

    await notifier.deleteAddress('a1');
    expect(repo.deleteCalls, 1);
    expect(container.read(addressesProvider).data!.map((a) => a.id), ['a2']);
  });
}
