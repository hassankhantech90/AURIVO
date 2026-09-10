import 'package:aurivo/features/authentication/presentation/login_page.dart';
import 'package:aurivo/features/authentication/presentation/signup_page.dart';
import 'package:aurivo/features/authentication/presentation/forgot_password_page.dart';
import 'package:aurivo/features/authentication/presentation/otp_page.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(child: MaterialApp(home: child));
}

void main() {
  group('Authentication widgets', () {
    testWidgets('LoginPage shows expected actions', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));

      expect(find.text('Email / Phone'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      // Remember Me removed (was a non-functional no-op); Forgot Password stays.
      expect(find.text('Remember Me'), findsNothing);
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('SignupPage shows terms checkbox and fields', (tester) async {
      await tester.pumpWidget(_wrap(const SignupPage()));

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('I accept the Terms & Conditions'), findsOneWidget);
    });

    testWidgets('ForgotPasswordPage shows send code form', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordPage()));

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send Code'), findsOneWidget);
    });

    testWidgets('OtpPage shows six text fields and verify button', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const OtpPage(flow: AuthFlow.signup)));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Verify'), findsOneWidget);
    });
  });
}
