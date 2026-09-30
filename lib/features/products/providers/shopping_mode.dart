import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the buyer is browsing the retail catalogue or the wholesale
/// catalogue (products that offer tiered/bulk pricing). Toggled from the Home
/// header and remembered on this device (defaults to retail).
enum ShoppingMode { retail, wholesale }

final shoppingModeProvider =
    StateNotifierProvider<ShoppingModeNotifier, ShoppingMode>(
      (ref) => ShoppingModeNotifier(),
    );

/// Holds the active [ShoppingMode], restoring the saved choice on creation and
/// persisting every change. Storage is best-effort: if SharedPreferences is
/// unavailable the mode simply stays session-only.
class ShoppingModeNotifier extends StateNotifier<ShoppingMode> {
  ShoppingModeNotifier({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance,
      super(ShoppingMode.retail) {
    _restore();
  }

  static const _key = 'home.shopping_mode';

  final Future<SharedPreferences> Function() _preferences;
  bool _changed = false;

  Future<void> _restore() async {
    try {
      final saved = (await _preferences()).getString(_key);
      // A choice made while restoring wins over the stored one.
      if (!mounted || _changed) return;
      state = ShoppingMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => state,
      );
    } catch (_) {
      // Storage unavailable — keep the default.
    }
  }

  Future<void> set(ShoppingMode mode) async {
    _changed = true;
    if (mode == state) return;
    state = mode;
    try {
      await (await _preferences()).setString(_key, mode.name);
    } catch (_) {
      // Storage unavailable — the change still applies for this session.
    }
  }
}
