import 'package:aurivo/app.dart';
import 'package:aurivo/features/authentication/domain/authentication_constants.dart';
import 'package:aurivo/features/authentication/presentation/onboarding_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Aurivo app routes first launch to onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: AurivoApp()));
    await tester.pump(AuthenticationConstants.splashDuration);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}
