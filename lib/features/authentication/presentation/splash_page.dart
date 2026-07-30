import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/authentication_constants.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/authentication_widgets.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDurations.slow);
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.standard,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.standard),
    );

    _controller.forward();
    _navigateAfterSplash();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.wait([
      Future<void>.delayed(AuthenticationConstants.splashDuration),
      ref.read(sharedPreferencesProvider.future),
    ]);

    if (!mounted) {
      return;
    }

    final hasSeenOnboarding = ref.read(hasSeenOnboardingProvider);
    context.go(hasSeenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softCream,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AurivoLogo(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The Jewellery Marketplace',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.graphite,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
