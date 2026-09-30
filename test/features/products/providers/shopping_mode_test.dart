import 'package:aurivo/features/products/providers/shopping_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the restore/persist futures settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('defaults to retail when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ShoppingModeNotifier();
    await _settle();
    expect(notifier.state, ShoppingMode.retail);
  });

  test('restores the saved mode on creation', () async {
    SharedPreferences.setMockInitialValues({'home.shopping_mode': 'wholesale'});
    final notifier = ShoppingModeNotifier();
    await _settle();
    expect(notifier.state, ShoppingMode.wholesale);
  });

  test('persists a change so the next launch restores it', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ShoppingModeNotifier();
    await _settle();

    await notifier.set(ShoppingMode.wholesale);

    expect(notifier.state, ShoppingMode.wholesale);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('home.shopping_mode'), 'wholesale');
    final next = ShoppingModeNotifier();
    await _settle();
    expect(next.state, ShoppingMode.wholesale);
  });

  test('ignores an unknown stored value', () async {
    SharedPreferences.setMockInitialValues({'home.shopping_mode': 'bogus'});
    final notifier = ShoppingModeNotifier();
    await _settle();
    expect(notifier.state, ShoppingMode.retail);
  });

  test('stays usable (session-only) when storage fails', () async {
    final notifier = ShoppingModeNotifier(
      preferences: () async => throw StateError('no storage'),
    );
    await _settle();
    expect(notifier.state, ShoppingMode.retail);

    await notifier.set(ShoppingMode.wholesale);
    expect(notifier.state, ShoppingMode.wholesale);
  });
}
