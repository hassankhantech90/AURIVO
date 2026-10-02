import 'package:aurivo/features/authentication/widgets/app_logo.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:aurivo/shared/widgets/brand/brand_wordmark_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the artwork ratio and is announced as Pareezay.Hub', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandWordmark(height: 30))),
      ),
    );

    final size = tester.getSize(find.byType(BrandWordmark));
    expect(size.height, 30);
    expect(
      size.width,
      closeTo(30 * brandWordmarkWidth / brandWordmarkHeight, 0.01),
    );
    expect(find.bySemanticsLabel('Pareezay.Hub'), findsOneWidget);
    expect(tester.takeException(), isNull); // path data parses and paints
    handle.dispose();
  });

  testWidgets('app logo fits a narrow screen without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppLogo())),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppLogo)).width, lessThanOrEqualTo(240));
  });

  test('path data is well-formed (only M/L/C/Q/Z commands)', () {
    final commands = RegExp(
      '[A-Za-z]',
    ).allMatches(brandWordmarkPath).map((m) => m[0]);
    expect(commands.toSet().difference({'M', 'L', 'C', 'Q', 'Z'}), isEmpty);
    expect(commands.where((c) => c == 'Z').length, greaterThan(10));
  });
}
