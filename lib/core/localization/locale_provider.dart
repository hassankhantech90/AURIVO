import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Languages the app can show (Requirements Doc §9: English at launch,
/// Urdu-ready). Urdu renders right-to-left automatically.
const supportedAppLocales = [Locale('en'), Locale('ur')];

/// The chosen app language, remembered on this device (defaults to English).
final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>(
  (ref) => AppLocaleNotifier(),
);

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance,
      super(const Locale('en')) {
    _restore();
  }

  static const _key = 'settings.locale';
  final Future<SharedPreferences> Function() _preferences;
  bool _changed = false;

  Future<void> _restore() async {
    try {
      final code = (await _preferences()).getString(_key);
      if (!mounted || _changed || code == null) return;
      if (supportedAppLocales.any((l) => l.languageCode == code)) {
        state = Locale(code);
      }
    } catch (_) {
      // Storage unavailable — stay on English.
    }
  }

  Future<void> set(Locale locale) async {
    _changed = true;
    if (locale == state) return;
    state = locale;
    try {
      await (await _preferences()).setString(_key, locale.languageCode);
    } catch (_) {
      // Session-only when storage is unavailable.
    }
  }
}

/// `context.l10n` — localized strings, falling back to English where no
/// localization delegate is installed (e.g. isolated widget tests).
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}
