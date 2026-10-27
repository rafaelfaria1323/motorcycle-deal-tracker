import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:motorcycle_deal_tracker/app/app.dart';
import 'package:motorcycle_deal_tracker/app/di/injection.dart';
import 'package:motorcycle_deal_tracker/app/router/app_router.dart';
import 'package:motorcycle_deal_tracker/app/router/app_routes.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/alerts_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_detail_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/alerts_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/dashboard_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';

import 'support/interface_fixture.dart';

@JS('document.documentElement.lang')
external JSString get _documentLanguage;

Future<void> _tab(WidgetTester tester, String label) async {
  final navigation = find.byWidgetPredicate(
    (widget) => widget is NavigationBar || widget is NavigationRail,
  );
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _backTo(WidgetTester tester, String location) async {
  await tester.tap(find.byType(BackButton));
  // Browser history changes arrive through a platform event, not a frame.
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (appRouter.routeInformationProvider.value.uri.path == location) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Back did not return to $location');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;

  testWidgets('browse, save and apply a search, then return from an alert', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await fixture.initialize();
    getIt.registerFactory<ListingDetailCubit>(
      () => ListingDetailCubit(fixture.repository),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.dispose();
      await getIt.reset();
    });

    appRouter.go(AppRoutes.deals);
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('6 anúncios'), findsOneWidget);

    await _tab(tester, 'Pesquisas');
    await tester.tap(
      find.text(savedSearchName(fixture.searchesRepository.values.single)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(fixture.listings.state.filters.maxPrice, 7000);
    expect(fixture.listings.state.filters.minYear, 2022);

    final year = find.widgetWithText(InputChip, 'desde 2022');
    await tester.ensureVisible(year);
    await tester.tap(
      find.descendant(of: year, matching: find.byTooltip('Remover filtro')),
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(TextButton, 'Guardar pesquisa');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Até sete mil');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values, hasLength(2));

    await _tab(tester, 'Pesquisas');
    await tester.tap(find.text('Até sete mil'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.deals);
    expect(fixture.listings.state.filters.maxPrice, 7000);
    expect(fixture.listings.state.filters.minYear, isNull);
    expect(
      find.widgetWithText(TextButton, 'Pesquisa guardada'),
      findsOneWidget,
    );

    final listing = find.text('Matosinhos, a 8 km').first;
    await tester.ensureVisible(listing);
    await tester.tap(listing);
    await tester.pumpAndSettle();
    expect(find.byType(ListingDetailPage), findsOneWidget);
    await _backTo(tester, AppRoutes.deals);
    expect(find.byType(DashboardPage), findsOneWidget);

    await _tab(tester, 'Alertas');
    final alert = fixture.alertsRepository.values.first;
    final title = find.text(alertTitle(alert));
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(
      appRouter.routeInformationProvider.value.uri.path,
      AppRoutes.listingDetail(alert.listing.id),
    );
    expect(fixture.alertsRepository.markedRead, [alert.id]);
    await _backTo(tester, AppRoutes.alerts);
    expect(find.byType(AlertsPage), findsOneWidget);

    expect(await fixture.languages.select(AppLanguage.english), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Alerts'), findsWidgets);
    expect(
      find.text(alertTitle(alert, language: AppLanguage.english)),
      findsOneWidget,
    );
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.alerts);
    expect(_documentLanguage.toDart, 'en-GB');

    expect(await fixture.languages.select(AppLanguage.portuguese), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Alertas'), findsWidgets);
    expect(_documentLanguage.toDart, 'pt-PT');
    expect(tester.takeException(), isNull);
  });
}
