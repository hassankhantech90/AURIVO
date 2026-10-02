import 'package:aurivo/core/localization/locale_provider.dart';
import 'package:aurivo/core/router/main_shell.dart';
import 'package:aurivo/features/cms/domain/entities/cms_entities.dart';
import 'package:aurivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  supportedLocales: supportedAppLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  testWidgets('Urdu shows translated tab labels and lays out right-to-left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Locale('ur'),
        const MainShell(location: '/', child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('ہوم'), findsOneWidget);
    expect(find.byTooltip('آرڈرز'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(MainShell)));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('English is the default and the l10n fallback', (tester) async {
    // No delegates installed: context.l10n still resolves (English).
    await tester.pumpWidget(
      const MaterialApp(
        home: MainShell(location: '/', child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Home'), findsOneWidget);
  });

  test('language choice persists across launches', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppLocaleNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(first.state, const Locale('en'));
    await first.set(const Locale('ur'));

    final next = AppLocaleNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(next.state, const Locale('ur'));
  });

  test('CMS content falls back to English without a translation', () {
    final page = CmsPage.fromMap({
      'id': '1',
      'slug': 'faq-returns',
      'kind': 'faq',
      'title': 'Can I return an item?',
      'body': 'Yes.',
      'translations': {
        'ur': {'title': 'کیا میں کوئی چیز واپس کر سکتا ہوں؟'},
      },
    });
    expect(page.titleIn('ur'), 'کیا میں کوئی چیز واپس کر سکتا ہوں؟');
    expect(page.bodyIn('ur'), 'Yes.'); // no Urdu body -> English
    expect(page.titleIn('en'), 'Can I return an item?');
    expect(parseTranslations('not a map'), isEmpty);
  });
}
