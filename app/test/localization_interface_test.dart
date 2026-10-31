import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/app/di/injection.dart';
import 'package:motorcycle_deal_tracker/app/router/app_routes.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/language_cubit.dart';

import '../integration_test/support/interface_fixture.dart';

Future<({InterfaceFixture fixture, GoRouter router})> _open(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  bool signedIn = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 900);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });
  final fixture = InterfaceFixture(
    language: AppLanguage.english,
    signedIn: signedIn,
  );
  await fixture.initialize();
  final router = fixture.router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    interfaceApp(
      router,
      textScale: textScale,
      languageCubit: getIt<LanguageCubit>(),
    ),
  );
  await tester.pumpAndSettle();
  return (fixture: fixture, router: router);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInterfaceFonts);
  tearDown(getIt.reset);

  testWidgets('English reaches the actual navigation and deals page', (
    tester,
  ) async {
    await _open(tester);
    // Ofertas' toolbar, in English; the intro shows only on an empty list (F.3).
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('6 listings'), findsOneWidget);
    expect(find.text('Searches'), findsWidgets);
    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('More'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [(320.0, 2.0), (900.0, 1.0), (1440.0, 1.0)]) {
    testWidgets('English offers fit ${width}px at ${scale}x text', (
      tester,
    ) async {
      await _open(tester, width: width, textScale: scale);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('6 listings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('searches, alerts, filters and settings use English', (
    tester,
  ) async {
    await _open(tester, signedIn: true);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Searches'));
    await tester.pumpAndSettle();
    expect(find.text('Your searches'), findsOneWidget);
    expect(find.text('New search'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('What changed'), findsOneWidget);
    expect(find.byTooltip('Mark all as read'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Deals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum price (EUR)'), findsOneWidget);
    expect(find.text('Maximum mileage (km)'), findsOneWidget);
    Navigator.of(tester.element(find.text('Maximum price (EUR)'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(find.text('Your garage'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the language picker saves the account choice without resetting the route',
    (tester) async {
      final opened = await _open(tester, signedIn: true);
      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();
      final languageTile = find.widgetWithText(ListTile, 'Language');
      await _reveal(tester, languageTile);
      await tester.tap(languageTile);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(RadioListTile<AppLanguage>, 'Português (Portugal)'),
      );
      await tester.pumpAndSettle();
      expect(opened.fixture.languageRepository.saves, [
        ('interface-user', AppLanguage.portuguese),
      ]);
      expect(
        opened.router.routeInformationProvider.value.uri.path,
        AppRoutes.more,
      );
      await tester.scrollUntilVisible(
        find.text('A sua garagem'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('A sua garagem'), findsOneWidget);
      expect(find.text('Ofertas'), findsWidgets);
      expect(find.text('Your garage'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open detail tab changes language but never translates seller content',
    (tester) async {
      final opened = await _open(tester);
      final location = AppRoutes.listingDetail(interfaceListing(0).id);
      opened.router.go(location);
      await tester.pumpAndSettle();
      await _reveal(tester, find.byType(TabBar));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mota de garagem'), findsOneWidget);
      expect(
        await opened.fixture.languages.select(AppLanguage.portuguese),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(opened.router.routeInformationProvider.value.uri.path, location);
      expect(find.text('Detalhes'), findsOneWidget);
      expect(find.textContaining('Mota de garagem'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an existing load failure is rendered again in the selected language',
    (tester) async {
      final opened = await _open(tester);
      opened.fixture.repository.fail = true;
      await opened.fixture.listings.load();
      await tester.pumpAndSettle();
      expect(find.text('Could not load deals'), findsOneWidget);
      await opened.fixture.languages.select(AppLanguage.portuguese);
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar as ofertas'), findsOneWidget);
      expect(find.text('Could not load deals'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
