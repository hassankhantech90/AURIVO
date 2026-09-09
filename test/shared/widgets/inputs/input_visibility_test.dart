import 'package:aurivo/core/theme/colors.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/features/authentication/widgets/auth_otp_field.dart';
import 'package:aurivo/shared/widgets/inputs/luxury_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the dark-mode "white text on white input fill" invisibility bug:
/// input fill is always pureWhite, so entered text + labels must be on-light
/// in both themes.
Widget _host(Widget child, ThemeData theme) =>
    MaterialApp(theme: theme, home: Scaffold(body: child));

Color? _enteredTextColor(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first).style.color;

void main() {
  group('entered-text color on the always-white input surface', () {
    testWidgets('CustomTextField (dark): on-light charcoal, not the white fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CustomTextField(labelText: 'Email'), AppTheme.dark),
      );
      await tester.enterText(find.byType(EditableText).first, 'user@aurivo.pk');
      await tester.pump();
      expect(_enteredTextColor(tester), AppColors.charcoal);
      expect(_enteredTextColor(tester), isNot(AppColors.pureWhite)); // != fill
    });

    testWidgets('CustomTextField (light): unchanged charcoal', (tester) async {
      await tester.pumpWidget(
        _host(const CustomTextField(labelText: 'Email'), AppTheme.light),
      );
      await tester.enterText(find.byType(EditableText).first, 'user@aurivo.pk');
      await tester.pump();
      expect(_enteredTextColor(tester), AppColors.charcoal);
    });

    testWidgets('PasswordTextField (dark): obscured text readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PasswordTextField(labelText: 'Password'), AppTheme.dark),
      );
      await tester.enterText(find.byType(EditableText).first, 'Secret123!');
      await tester.pump();
      expect(_enteredTextColor(tester), AppColors.charcoal);
      expect(_enteredTextColor(tester), isNot(AppColors.pureWhite));
    });

    testWidgets('AuthOtpField (dark): digits readable jetBlack', (tester) async {
      await tester.pumpWidget(_host(AuthOtpField(onChanged: (_) {}), AppTheme.dark));
      await tester.enterText(find.byType(EditableText).first, '1');
      await tester.pump();
      expect(_enteredTextColor(tester), AppColors.jetBlack);
      expect(_enteredTextColor(tester), isNot(AppColors.pureWhite));
    });
  });

  group('label colors on the always-white input surface', () {
    test('dark theme labelStyle is on-light charcoal, not white', () {
      final color = AppTheme.dark.inputDecorationTheme.labelStyle?.color;
      expect(color, AppColors.charcoal);
      expect(color, isNot(AppColors.pureWhite));
    });

    test('dark floatingLabelStyle: gold focused / red error / charcoal default', () {
      final style = AppTheme.dark.inputDecorationTheme.floatingLabelStyle;
      expect(style, isA<WidgetStateTextStyle>());
      final resolved = style! as WidgetStateTextStyle;
      expect(resolved.resolve({WidgetState.focused}).color, AppColors.primaryGold);
      expect(resolved.resolve({WidgetState.error}).color, AppColors.error);
      expect(resolved.resolve(<WidgetState>{}).color, AppColors.charcoal);
    });

    test('light theme labelStyle unchanged (charcoal)', () {
      expect(
        AppTheme.light.inputDecorationTheme.labelStyle?.color,
        AppColors.charcoal,
      );
    });
  });
}
