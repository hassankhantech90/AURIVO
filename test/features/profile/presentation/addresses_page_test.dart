import 'package:aurivo/features/profile/domain/entities/address.dart';
import 'package:aurivo/features/profile/domain/repositories/profile_repository.dart';
import 'package:aurivo/features/profile/presentation/addresses_page.dart';
import 'package:aurivo/features/profile/presentation/widgets/address_form_sheet.dart';
import 'package:aurivo/features/profile/providers/profile_providers.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Address _address({String id = 'a1', bool isDefault = false, String? label}) =>
    Address(
      id: id,
      profileId: 'p1',
      addressType: 'shipping',
      label: label,
      recipientName: 'Aiman',
      phone: '03000000000',
      addressLine1: '1 Mall Road',
      city: 'Lahore',
      province: 'Punjab',
      isDefault: isDefault,
    );

/// Minimal in-memory ProfileRepository (addresses only; the rest via noSuchMethod).
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({List<Address> addresses = const []})
    : _addresses = [...addresses];
  final List<Address> _addresses;

  int addCalls = 0;

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
    final a = _address(id: 'new', label: label, isDefault: isDefault);
    _addresses.add(a);
    return a;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(ProfileRepository repo, Widget child) {
  return ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('empty state when there are no addresses', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeProfileRepository(), const AddressesPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No addresses yet'), findsOneWidget);
    expect(find.text('Add address'), findsOneWidget);
  });

  testWidgets('renders addresses with a default badge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeProfileRepository(
          addresses: [_address(label: 'Home', isDefault: true)],
        ),
        const AddressesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('address form validates required fields', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeProfileRepository();
    await tester.pumpWidget(
      _wrap(
        repo,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AddressFormSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Submit empty -> validation error, no add call.
    await tester.tap(find.widgetWithText(LoadingButton, 'Add address'));
    await tester.pumpAndSettle();
    expect(repo.addCalls, 0);
    expect(find.textContaining('are required'), findsOneWidget);
  });
}
