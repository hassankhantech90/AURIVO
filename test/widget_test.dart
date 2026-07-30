import 'package:aurivo/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Aurivo app starts', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AurivoApp()));

    expect(find.byType(AurivoApp), findsOneWidget);
  });
}
