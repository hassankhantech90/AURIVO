import 'package:aurivo/core/theme/theme_exports.dart';
import 'package:aurivo/shared/widgets/common/segmented_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required int selectedIndex,
  required ValueChanged<int> onSelected,
}) => MaterialApp(
  home: Scaffold(
    body: SegmentedTabs(
      labels: const ['Gold', 'Silver', 'Artificial'],
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    ),
  ),
);

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  testWidgets('renders every segment label', (tester) async {
    await tester.pumpWidget(_host(selectedIndex: 0, onSelected: (_) {}));

    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('Artificial'), findsOneWidget);
  });

  testWidgets('only the selected segment is emphasised', (tester) async {
    await tester.pumpWidget(_host(selectedIndex: 1, onSelected: (_) {}));

    expect(_labelStyle(tester, 'Silver').fontWeight, FontWeight.w600);
    expect(_labelStyle(tester, 'Silver').color, AppColors.jetBlack);
    expect(_labelStyle(tester, 'Gold').fontWeight, FontWeight.w500);
    expect(_labelStyle(tester, 'Gold').color, AppColors.mediumGrey);
  });

  testWidgets('tapping a segment reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _host(selectedIndex: 0, onSelected: (index) => tapped = index),
    );

    await tester.tap(find.text('Artificial'));
    expect(tapped, 2);
  });
}
