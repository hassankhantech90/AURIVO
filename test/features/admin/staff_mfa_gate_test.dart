import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/admin/data/staff_mfa_service.dart';
import 'package:aurivo/features/admin/presentation/widgets/staff_mfa_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMfa extends StaffMfaService {
  _FakeMfa(this.current) : super(const SupabaseService());

  StaffMfaState current;
  static const acceptCode = '123456';
  final List<String> calls = [];

  @override
  Future<StaffMfaState> state() async => current;

  @override
  Future<TotpSetup> startEnrolment() async {
    calls.add('enrol');
    return const TotpSetup(
      factorId: 'f1',
      secret: 'JBSWY3DPEHPK3PXP',
      uri: 'otpauth://totp/AURIVO',
    );
  }

  @override
  Future<void> verify(String factorId, String code) async {
    calls.add('verify:$factorId:$code');
    if (code != acceptCode) throw Exception('bad code');
    current = StaffMfaState.satisfied;
  }

  @override
  Future<void> verifyExisting(String code) async {
    calls.add('existing:$code');
    if (code != acceptCode) throw Exception('bad code');
    current = StaffMfaState.satisfied;
  }
}

Future<void> _pump(WidgetTester tester, _FakeMfa mfa) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [staffMfaServiceProvider.overrideWithValue(mfa)],
      child: const MaterialApp(
        home: Scaffold(body: StaffMfaGate(child: Text('CONSOLE'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first time: enrol with the key, verify, then console opens', (
    tester,
  ) async {
    final mfa = _FakeMfa(StaffMfaState.needsEnrolment);
    await _pump(tester, mfa);
    expect(find.text('CONSOLE'), findsNothing);
    expect(find.text('Set up two-factor authentication'), findsOneWidget);

    await tester.tap(find.text('Start set-up'));
    await tester.pumpAndSettle();
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify & continue'));
    await tester.pumpAndSettle();

    expect(mfa.calls, ['enrol', 'verify:f1:123456']);
    expect(find.text('CONSOLE'), findsOneWidget);
  });

  testWidgets('enrolled: a wrong code is rejected, the right one unlocks', (
    tester,
  ) async {
    final mfa = _FakeMfa(StaffMfaState.needsCode);
    await _pump(tester, mfa);
    expect(find.text('Enter your authentication code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.textContaining('did not match'), findsOneWidget);
    expect(find.text('CONSOLE'), findsNothing);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('CONSOLE'), findsOneWidget);
  });

  testWidgets('already verified sessions go straight to the console', (
    tester,
  ) async {
    await _pump(tester, _FakeMfa(StaffMfaState.satisfied));
    expect(find.text('CONSOLE'), findsOneWidget);
  });
}
