import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/onboarding_local_data_source.dart';
import '../domain/onboarding_repository.dart';
import '../repositories/onboarding_repository_impl.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider).requireValue;

  return OnboardingRepositoryImpl(
    localDataSource: OnboardingLocalDataSource(preferences: preferences),
  );
});

final hasSeenOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).hasSeenOnboarding();
});

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(
        repository: ref.watch(onboardingRepositoryProvider),
      );
    });

/// UI state for the onboarding PageView.
class OnboardingState {
  const OnboardingState({required this.currentPage, this.isCompleting = false});

  final int currentPage;
  final bool isCompleting;

  OnboardingState copyWith({int? currentPage, bool? isCompleting}) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      isCompleting: isCompleting ?? this.isCompleting,
    );
  }
}

/// Riverpod controller for onboarding page progress and completion.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier({required OnboardingRepository repository})
    : _repository = repository,
      super(const OnboardingState(currentPage: 0));

  final OnboardingRepository _repository;

  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  Future<void> complete() async {
    state = state.copyWith(isCompleting: true);
    await _repository.setHasSeenOnboarding(true);
    state = state.copyWith(isCompleting: false);
  }
}
