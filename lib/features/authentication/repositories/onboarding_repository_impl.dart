import '../data/datasources/onboarding_local_data_source.dart';
import '../domain/onboarding_repository.dart';

/// SharedPreferences-backed onboarding repository implementation.
class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl({
    required OnboardingLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final OnboardingLocalDataSource _localDataSource;

  @override
  bool hasSeenOnboarding() {
    return _localDataSource.hasSeenOnboarding();
  }

  @override
  Future<void> setHasSeenOnboarding(bool value) {
    return _localDataSource.setHasSeenOnboarding(value);
  }
}
