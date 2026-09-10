import 'package:aurivo/core/theme/colors.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/presentation/login_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:aurivo/features/authentication/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the dark-mode "white text on the light auth surface" bug: AuthScaffold
/// keeps a softCream/white surface in both themes, so its text subtree must use
/// on-light colours (scoped light TextTheme), not the global dark TextTheme.
Color? _color(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style?.color;

Widget _login(ThemeData theme) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      const FakeAuthRepository(delay: Duration.zero),
    ),
  ],
  child: MaterialApp(theme: theme, home: const LoginPage()),
);

void main() {
  group('Login text on the light auth surface', () {
    testWidgets('dark: heading / or / fields are on-light (not white)', (
      t,
    ) async {
      await t.pumpWidget(_login(AppTheme.dark));
      await t.pump();
      expect(_color(t, 'Welcome Back'), AppColors.jetBlack);
      expect(_color(t, 'or'), AppColors.mediumGrey);
      for (final s in ['Welcome Back', 'or']) {
        expect(_color(t, s), isNot(AppColors.pureWhite));
      }
    });

    testWidgets('light: unchanged', (t) async {
      await t.pumpWidget(_login(AppTheme.light));
      await t.pump();
      expect(_color(t, 'Welcome Back'), AppColors.jetBlack);
      expect(_color(t, 'or'), AppColors.mediumGrey);
    });
  });

  testWidgets('shared: any AuthScaffold heading + inherited body are on-light '
      'in dark mode (proves the fix beyond Login)', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AuthScaffold(
          title: 'Create Account',
          subtitle: 'Join AURIVO',
          child: Builder(
            builder: (ctx) =>
                Text('Body text', style: Theme.of(ctx).textTheme.bodyMedium),
          ),
        ),
      ),
    );
    await t.pump();
    expect(_color(t, 'Create Account'), AppColors.jetBlack);
    expect(_color(t, 'Body text'), AppColors.charcoal);
    expect(_color(t, 'Create Account'), isNot(AppColors.pureWhite));
    // Subtitle keeps its explicit graphite colour (unchanged by the fix).
    expect(_color(t, 'Join AURIVO'), AppColors.graphite);
  });
}
