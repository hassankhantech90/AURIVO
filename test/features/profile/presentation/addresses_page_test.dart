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
  int updateCalls = 0;
  String? lastProvince;
  String? lastPhone;

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
    lastProvince = province;
    lastPhone = phone;
    final a = _address(id: 'new', label: label, isDefault: isDefault);
    _addresses.add(a);
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
    lastProvince = province;
    return _address(id: addressId, label: label);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(
  ProfileRepository repo,
  Widget child, {
  double insetBottom = 0,
  double textScale = 1.0,
}) {
  final needsBuilder = insetBottom != 0 || textScale != 1.0;
  return ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      builder: !needsBuilder
          ? null
          : (context, w) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: EdgeInsets.only(bottom: insetBottom),
                textScaler: TextScaler.linear(textScale),
              ),
              child: w!,
            ),
      home: child,
    ),
  );
}

/// Opens the AddressFormSheet on a large canvas so the whole form is reachable.
Future<void> _openForm(
  WidgetTester tester,
  ProfileRepository repo, {
  Address? initial,
  Size size = const Size(1200, 3600),
  double insetBottom = 0,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _wrap(
      repo,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => AddressFormSheet.show(context, initial: initial),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      insetBottom: insetBottom,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
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

  testWidgets('valid address with a selected province submits', (tester) async {
    final repo = _FakeProfileRepository();
    await _openForm(tester, repo);

    await tester.enterText(find.byType(TextField).at(1), 'Ali Khan');
    await tester.enterText(find.byType(TextField).at(2), '0300 1234567');
    await tester.enterText(find.byType(TextField).at(3), 'House 1, Street 2');
    await tester.enterText(find.byType(TextField).at(6), 'Lahore');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punjab').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(LoadingButton, 'Add address'));
    await tester.pumpAndSettle();

    expect(repo.addCalls, 1);
    expect(repo.lastProvince, 'Punjab');
  });

  testWidgets('invalid phone shows a field-specific error, no submit', (
    tester,
  ) async {
    final repo = _FakeProfileRepository();
    await _openForm(tester, repo);

    await tester.enterText(find.byType(TextField).at(1), 'Ali Khan');
    await tester.enterText(find.byType(TextField).at(2), '123'); // invalid
    await tester.enterText(find.byType(TextField).at(3), 'House 1, Street 2');
    await tester.enterText(find.byType(TextField).at(6), 'Lahore');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punjab').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(LoadingButton, 'Add address'));
    await tester.pumpAndSettle();

    expect(repo.addCalls, 0);
    expect(find.textContaining('valid Pakistan phone'), findsOneWidget);
  });

  testWidgets('province dropdown offers the allowed values', (tester) async {
    await _openForm(tester, _FakeProfileRepository());
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Sindh'), findsOneWidget);
    expect(find.text('Khyber Pakhtunkhwa'), findsOneWidget);
  });

  testWidgets('form has no overflow at 320px', (tester) async {
    await _openForm(
      tester,
      _FakeProfileRepository(),
      size: const Size(320, 2600),
    );
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(LoadingButton, 'Add address'), findsOneWidget);
  });

  testWidgets('no overflow at 375px with 1.3x text scale', (tester) async {
    await _openForm(
      tester,
      _FakeProfileRepository(),
      size: const Size(375, 2600),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    // Province selector and submit remain present/usable.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.widgetWithText(LoadingButton, 'Add address'), findsOneWidget);
  });

  testWidgets('submit remains reachable with the keyboard open', (
    tester,
  ) async {
    await _openForm(
      tester,
      _FakeProfileRepository(),
      size: const Size(375, 1400),
      insetBottom: 500, // simulated keyboard height
    );
    expect(tester.takeException(), isNull);
    // The submit button stays in the (scrollable) tree above the keyboard.
    expect(find.widgetWithText(LoadingButton, 'Add address'), findsOneWidget);
  });

  testWidgets('editing an address updates it with the prefilled province', (
    tester,
  ) async {
    final repo = _FakeProfileRepository();
    await _openForm(tester, repo, initial: _address(label: 'Home'));

    await tester.tap(find.widgetWithText(LoadingButton, 'Save address'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastProvince, 'Punjab');
  });
}
