/// Repository contract for onboarding local state.
abstract class OnboardingRepository {
  bool hasSeenOnboarding();

  Future<void> setHasSeenOnboarding(bool value);
}
