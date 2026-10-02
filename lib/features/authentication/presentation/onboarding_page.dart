import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../data/onboarding_slides.dart';
import '../domain/authentication_constants.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/authentication_widgets.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingProvider.notifier).complete();

    if (!mounted) {
      return;
    }

    context.go(AppRoutes.login);
  }

  void _goToNextPage(int currentPage) {
    if (currentPage == AuthenticationConstants.onboardingPageCount - 1) {
      _completeOnboarding();
      return;
    }

    _pageController.nextPage(
      duration: AppDurations.slow,
      curve: AppAnimations.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(sharedPreferencesProvider);

    return preferences.when(
      data: (_) => _OnboardingContent(
        pageController: _pageController,
        onComplete: _completeOnboarding,
        onNext: _goToNextPage,
      ),
      loading: () => const Scaffold(
        backgroundColor: AppColors.softCream,
        body: LoadingIndicator(),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppColors.softCream,
        body: ErrorStateWidget(message: error.toString()),
      ),
    );
  }
}

class _OnboardingContent extends ConsumerWidget {
  const _OnboardingContent({
    required this.pageController,
    required this.onComplete,
    required this.onNext,
  });

  final PageController pageController;
  final Future<void> Function() onComplete;
  final void Function(int currentPage) onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final currentPage = state.currentPage;
    final isLastPage =
        currentPage == AuthenticationConstants.onboardingPageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.softCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(compact: true),
                  AnimatedOpacity(
                    opacity: isLastPage ? 0 : 1,
                    duration: AppDurations.normal,
                    child: LuxuryTextButton(
                      label: 'Skip',
                      onPressed: isLastPage ? null : onComplete,
                      size: AppButtonSize.small,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: OnboardingSlides.items.length,
                onPageChanged: ref
                    .read(onboardingProvider.notifier)
                    .setCurrentPage,
                itemBuilder: (context, index) {
                  return OnboardingSlideView(
                    slide: OnboardingSlides.items[index],
                    isActive: index == currentPage,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  OnboardingPageIndicator(
                    currentPage: currentPage,
                    pageCount: OnboardingSlides.items.length,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: isLastPage ? 'Get Started' : 'Next',
                    icon: isLastPage
                        ? Icons.arrow_forward
                        : Icons.chevron_right,
                    isLoading: state.isCompleting,
                    onPressed: state.isCompleting
                        ? null
                        : () => onNext(currentPage),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
