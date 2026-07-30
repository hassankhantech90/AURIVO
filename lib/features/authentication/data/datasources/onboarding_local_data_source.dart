import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for onboarding completion state.
class OnboardingLocalDataSource {
  const OnboardingLocalDataSource({required SharedPreferences preferences})
    : _preferences = preferences;

  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  final SharedPreferences _preferences;

  bool hasSeenOnboarding() {
    return _preferences.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) {
    return _preferences.setBool(_hasSeenOnboardingKey, value);
  }
}
