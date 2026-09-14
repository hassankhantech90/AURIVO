import 'package:aurivo/features/authentication/widgets/auth_otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A6 coverage for the OTP entry widget: value/paste behaviour that is reliably
/// widget-testable. Focus-manager internals (auto-advance / backspace focus
/// movement) are intentionally left to manual/device testing to avoid brittle
/// tests that assert framework focus state.
void main() {
  Widget host(void Function(String) onChanged) => MaterialApp(
    home: Scaffold(body: AuthOtpField(onChanged: onChanged)),
  );

  testWidgets('a 6-digit paste is distributed across all six boxes', (
    tester,
  ) async {
    String? value;
    await tester.pumpWidget(host((v) => value = v));
    await tester.pump();

    // Entering the whole code into the first box exercises the paste path.
    await tester.enterText(find.byType(EditableText).first, '123456');
    await tester.pump();

    expect(value, '123456');
    final boxes = find.byType(EditableText);
    for (var i = 0; i < 6; i++) {
      expect(
        tester.widget<EditableText>(boxes.at(i)).controller.text,
        '${i + 1}',
      );
    }
  });

  testWidgets('non-digit characters are stripped from the entered value', (
    tester,
  ) async {
    String? value;
    await tester.pumpWidget(host((v) => value = v));
    await tester.pump();

    await tester.enterText(find.byType(EditableText).first, '12ab34');
    await tester.pump();

    // Only the digits survive; no letters reach the callback.
    expect(value, '1234');
    expect(value!.contains(RegExp('[^0-9]')), isFalse);
  });
}
