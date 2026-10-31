import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/app/di/injection.dart';
import 'package:motorcycle_deal_tracker/app/router/app_routes.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/widgets/section_card.dart';
import 'package:motorcycle_deal_tracker/core/widgets/state_message.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_card_preferences.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_card_preferences_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/favourites_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/photo_viewer_args.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/deal_score_badge.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/listing_card.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/photo_gallery.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/price_change_tag.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/listing_card_preferences_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../integration_test/support/interface_fixture.dart';

import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';

void _screen(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });
}

Future<GoRouter> _open(
  WidgetTester tester,
  InterfaceFixture fixture, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  String location = AppRoutes.deals,
}) async {
  _screen(tester, size);
  await fixture.initialize();
  final router = fixture.router(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    interfaceApp(router, textScale: textScale, dark: dark),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Mais › "Cartões dos anúncios", the only way in to the card choices.
final _cardChoices = find.widgetWithText(ListTile, 'Cartões dos anúncios');

Future<GoRouter> _openCardChoices(
  WidgetTester tester,
  InterfaceFixture fixture, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final router = await _open(
    tester,
    fixture,
    size: size,
    textScale: textScale,
    location: AppRoutes.more,
  );
  await _reveal(tester, _cardChoices);
  await tester.tap(_cardChoices);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _toggleCardField(WidgetTester tester, String label) async {
  final field = find.widgetWithText(CheckboxListTile, label);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> _swipe(
  WidgetTester tester,
  String id, {
  required bool delete,
  double fraction = 0.7,
}) async {
  final row = find.byKey(ValueKey('swipe-$id'));
  await _reveal(tester, row);
  final rect = tester.getRect(row);
  await tester.dragFrom(
    delete
        ? rect.centerRight - const Offset(24, 0)
        : rect.centerLeft + const Offset(24, 0),
    Offset(rect.width * fraction * (delete ? -1 : 1), 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInterfaceFonts);
  tearDown(getIt.reset);

  for (final scale in [1.0, 1.25]) {
    testWidgets('the count shares the toolbar row at ${scale}x', (
      tester,
    ) async {
      await _open(
        tester,
        InterfaceFixture(total: 45),
        size: const Size(900, 1000),
        textScale: scale,
      );
      final filters = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Filtros'),
      );
      final count = tester.getRect(find.text('40 anúncios carregados'));
      expect(count.center.dy, closeTo(filters.center.dy, 1));
      expect(count.left, greaterThan(filters.right));
      // Nothing above the toolbar: the ads start at once.
      expect(find.text('A próxima mota começa aqui.'), findsNothing);
      expect(find.text('Cartões'), findsNothing);
      expect(find.text('Guardar pesquisa'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the count wraps safely on a narrow enlarged screen', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(total: 45),
      size: const Size(320, 720),
      textScale: 2,
    );
    final count = tester.getRect(find.text('40 anúncios carregados'));
    final filters = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Filtros'),
    );
    expect(count.top, greaterThanOrEqualTo(filters.bottom));
    expect(count.right, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone fits Filtros and the sort on one row', (tester) async {
    await _open(tester, InterfaceFixture(), size: const Size(360, 800));
    final filters = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Filtros'),
    );
    final sort = tester.getRect(find.byTooltip('Ordenar'));
    expect(sort.center.dy, closeTo(filters.center.dy, 1));
    // The first ad starts in the top quarter of the screen.
    expect(
      tester.getTopLeft(find.byType(ListingCard).first).dy,
      lessThan(800 / 4),
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 900.0, 1440.0]) {
      testWidgets('offers fit ${width.toInt()}px, dark=$dark', (tester) async {
        await _open(
          tester,
          InterfaceFixture(),
          size: Size(width, 1000),
          dark: dark,
        );
        expect(find.text('A próxima mota começa aqui.'), findsNothing);
        expect(find.text('6 anúncios'), findsOneWidget);
        expect(find.byType(ListingCard), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('offers keep enlarged text readable in natural-height cards', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      size: const Size(320, 720),
      textScale: 2,
    );
    await _reveal(
      tester,
      find.byWidgetPredicate(
        (w) => w is ListingCard && w.listing.id == interfaceListing(0).id,
      ),
    );
    expect(find.byType(SliverGrid), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [660.0, 800.0]) {
    testWidgets('two-column cards fit ${width.toInt()}px with larger text', (
      tester,
    ) async {
      await _open(
        tester,
        InterfaceFixture(),
        size: Size(width, 1000),
        textScale: 1.25,
      );
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.1, 1.25]) {
    for (final preferences in [
      const ListingCardPreferences.defaults(),
      ListingCardPreferences(ListingCardField.values),
      ListingCardPreferences(const []),
    ]) {
      testWidgets(
        'grid cards fit long names with ${preferences.fields.length} fields at ${scale}x text',
        (tester) async {
          _screen(tester, const Size(660, 1000));
          await tester.pumpWidget(
            MaterialApp(
              locale: AppLanguage.portuguese.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: appLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Builder(
                      builder: (context) => Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 300,
                          height: ListingCard.gridHeight(
                            context,
                            preferences: preferences,
                          ),
                          child: ListingCard(
                            preferences: preferences,
                            listing: Listing(
                              id: 'long-model',
                              source: 'standvirtual',
                              url: 'https://www.standvirtual.com/motos/anuncio/test',
                              brand: 'Harley-Davidson',
                              model: 'Sportster S 1250 Revolution Max',
                              status: ListingStatus.active,
                              sellerType: SellerType.dealer,
                              sellerName: List.filled(
                                8,
                                'Motos e acessórios do Norte',
                              ).join(' '),
                              images: const [],
                              year: 2023,
                              mileage: 123456,
                              price: 12990,
                              initialPrice: 13990,
                              dealScore: 80,
                              riskScore: 10,
                              firstSeenAt: DateTime.utc(2026, 10, 23),
                              publishedAt: DateTime.utc(2026, 4, 3),
                              siteRefreshedAt: DateTime.utc(2026, 10, 24),
                              registrations: 1,
                              serviceBook: true,
                              origin: 'imported',
                              colour: 'blue',
                              warrantyUntil: DateTime.utc(2027, 3, 1),
                              dealerWarrantyMonths: 18,
                              location: 'Vila Nova de Gaia',
                              distanceKm: 128,
                            ),
                            onTap: () {},
                            onLongPress: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Comparar'), findsOneWidget);
          if (preferences.shows(ListingCardField.registrations)) {
            expect(find.text('Primeiro dono'), findsOneWidget);
          }
          if (preferences.shows(ListingCardField.sellerName)) {
            final seller = find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.data?.startsWith('Stand: ') ?? false),
            );
            expect(tester.widget<Text>(seller).maxLines, 2);
          }
          final card = find.byType(ListingCard);
          expect(
            tester.getSize(card).height,
            ListingCard.gridHeight(
              tester.element(card),
              preferences: preferences,
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('owners and publication can be chosen at ${scale}x text', (
      tester,
    ) async {
      final fixture = InterfaceFixture(signedIn: true);
      final router = await _openCardChoices(
        tester,
        fixture,
        size: const Size(320, 720),
        textScale: scale,
      );
      await _toggleCardField(tester, 'Donos / primeiro dono');
      await _toggleCardField(tester, 'Data de publicação');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      router.go(AppRoutes.deals);
      await tester.pumpAndSettle();
      final card = find.byType(ListingCard).first;
      await _reveal(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('Primeiro dono')),
        findsOneWidget,
      );
      final published = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.startsWith('Publicado: 09/10/2026') ?? false),
        ),
      );
      expect(published, findsOneWidget);
      expect(tester.widget<Text>(published).maxLines, isNull);
      expect(
        fixture.cardPreferencesRepository.value.shows(
          ListingCardField.registrations,
        ),
        isTrue,
      );
      expect(
        fixture.cardPreferencesRepository.value.shows(
          ListingCardField.publishedAt,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('card choices save, cancel and reset at ${scale}x text', (
      tester,
    ) async {
      final fixture = InterfaceFixture(signedIn: true);
      final router = await _openCardChoices(
        tester,
        fixture,
        size: const Size(320, 720),
        textScale: scale,
      );
      await _toggleCardField(tester, 'Quilometragem');
      await _toggleCardField(tester, 'Risk Score');
      expect(fixture.cardPreferencesRepository.saves, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        fixture.cardPreferencesRepository.value,
        const ListingCardPreferences.defaults(),
      );

      await tester.tap(_cardChoices);
      await tester.pumpAndSettle();
      await _toggleCardField(tester, 'Quilometragem');
      await _toggleCardField(tester, 'Risk Score');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(fixture.cardPreferencesRepository.saves, 1);
      expect(
        fixture.cardPreferencesRepository.value.shows(ListingCardField.mileage),
        isFalse,
      );
      router.go(AppRoutes.deals);
      await tester.pumpAndSettle();
      final card = find.byType(ListingCard).first;
      await _reveal(tester, card);
      expect(
        tester.widget<ListingCard>(card).preferences,
        fixture.cardPreferencesRepository.value,
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.speed)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('Risk Score: 10/100')),
        findsOneWidget,
      );

      router.go(AppRoutes.more);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_cardChoices);
      await tester.pumpAndSettle();
      await tester.tap(_cardChoices);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Repor predefinições'));
      await tester.tap(find.text('Repor predefinições'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(
        fixture.cardPreferencesRepository.value,
        const ListingCardPreferences.defaults(),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'saved choices apply to favourites without hiding essential state',
    (tester) async {
      final fixture = InterfaceFixture(signedIn: true);
      fixture.cardPreferencesRepository.value = ListingCardPreferences(const [
        ListingCardField.riskScore,
        ListingCardField.registrations,
        ListingCardField.publishedAt,
      ]);
      fixture.favouritesRepository.values.add(
        Favourite(
          listingId: interfaceListing(0).id,
          createdAt: DateTime.utc(2026, 10, 23),
          listing: interfaceListing(0),
          note: 'Ver no sábado',
        ),
      );
      await _open(tester, fixture, location: AppRoutes.favourites);
      final card = find.byType(ListingCard);
      expect(
        find.descendant(of: card, matching: find.text('Yamaha MT-07')),
        findsOneWidget,
      );
      expect(find.text('Risk Score: 10/100'), findsOneWidget);
      expect(find.text('Primeiro dono'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.startsWith('Publicado: 09/10/2026') ?? false),
        ),
        findsOneWidget,
      );
      expect(find.byType(DealScoreBadge), findsNothing);
      expect(find.byType(PriceChangeTag), findsNothing);
      expect(find.byIcon(Icons.speed), findsNothing);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Ver no sábado'), findsOneWidget);

      await getIt<ListingCardPreferencesCubit>().save(
        const ListingCardPreferences.defaults(),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.byType(DealScoreBadge), findsOneWidget);
      expect(find.byType(PriceChangeTag), findsOneWidget);
      expect(find.text('Risk Score: 10/100'), findsNothing);
      expect(find.text('Primeiro dono'), findsNothing);
    },
  );

  testWidgets(
    'a card with no optional fields retains removed and comparison controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLanguage.portuguese.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: ListingCard(
              preferences: ListingCardPreferences(const []),
              listing: const Listing(
                id: 'removed',
                source: 'olx',
                url: 'https://example.pt/removed',
                brand: 'Yamaha',
                model: 'MT-07',
                status: ListingStatus.removed,
                sellerType: SellerType.private,
                images: [],
                price: 6500,
                myColour: true,
              ),
              favourite: true,
              onLongPress: () {},
            ),
          ),
        ),
      );
      expect(find.text('Yamaha MT-07'), findsOneWidget);
      expect(find.text('Removido'), findsOneWidget);
      expect(find.text('Comparar'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Cor preferida'), findsNothing);
      expect(find.text('OLX'), findsNothing);
    },
  );

  testWidgets(
    'card preference load and save errors are visible and retryable',
    (tester) async {
      final fixture = InterfaceFixture(signedIn: true);
      fixture.cardPreferencesRepository.failReads = true;
      await _open(tester, fixture, location: AppRoutes.more);
      await _reveal(tester, _cardChoices);
      const loadError =
          'Não foi possível carregar as suas escolhas. Tente novamente.';
      expect(
        find.descendant(of: _cardChoices, matching: find.text(loadError)),
        findsOneWidget,
      );
      await tester.tap(_cardChoices);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(loadError),
        ),
        findsOneWidget,
      );
      fixture.cardPreferencesRepository.failReads = false;
      final retry = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Tentar novamente'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await _toggleCardField(tester, 'Quilometragem');
      fixture.cardPreferencesRepository.failWrites = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(
          'Não foi possível guardar as suas escolhas. Tente novamente.',
        ),
      );
      expect(
        find.text(
          'Não foi possível guardar as suas escolhas. Tente novamente.',
        ),
        findsOneWidget,
      );
      expect(fixture.cardPreferencesRepository.saves, 0);
      fixture.cardPreferencesRepository.failWrites = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.cardPreferencesRepository.saves, 1);
    },
  );

  testWidgets(
    'anonymous visitors keep default cards and are asked to sign in',
    (tester) async {
      final fixture = InterfaceFixture();
      await _open(tester, fixture, location: AppRoutes.more);
      await _reveal(tester, _cardChoices);
      expect(tester.widget<ListTile>(_cardChoices).enabled, isFalse);
      expect(
        find.descendant(
          of: _cardChoices,
          matching: find.text('Disponível com sessão iniciada'),
        ),
        findsOneWidget,
      );
      unawaited(showListingCardPreferences(tester.element(_cardChoices)));
      await tester.pumpAndSettle();
      expect(
        find.text('Inicie sessão para personalizar os cartões dos anúncios.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.cardPreferencesRepository.saves, 0);
    },
  );

  testWidgets('signing out closes an open card draft and clears its choices', (
    tester,
  ) async {
    final users = StreamController<User?>();
    addTearDown(users.close);
    final fixture = InterfaceFixture(signedIn: true, userChanges: users.stream);
    await _openCardChoices(tester, fixture);
    await _toggleCardField(tester, 'Risk Score');
    users.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(getIt<ListingCardPreferencesCubit>().state.userId, isNull);
    expect(
      getIt<ListingCardPreferencesCubit>().state.preferences,
      const ListingCardPreferences.defaults(),
    );
    expect(fixture.cardPreferencesRepository.saves, 0);
  });

  for (final lateSave in [false, true]) {
    testWidgets(
      'card dialog keeps the page beneath during ${lateSave ? 'a late save' : 'an account switch'}',
      (tester) async {
        final users = StreamController<User?>();
        addTearDown(users.close);
        final fixture = InterfaceFixture(
          signedIn: true,
          userChanges: users.stream,
        );
        final pendingSave = Completer<void>();
        if (lateSave) {
          fixture.cardPreferencesRepository.saveDelay = pendingSave.future;
        }
        final router = await _open(tester, fixture, location: AppRoutes.more);
        unawaited(router.push<void>(AppRoutes.favourites));
        await tester.pumpAndSettle();
        unawaited(
          showListingCardPreferences(
            tester.element(find.byType(FavouritesPage)),
          ),
        );
        await tester.pumpAndSettle();

        if (lateSave) {
          await _toggleCardField(tester, 'Quilometragem');
          await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
          await tester.pump();
          await tester.tapAt(const Offset(2, 2));
          await tester.pump();
          pendingSave.complete();
        } else {
          users.add(
            const User(
              id: 'another-user',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-25T00:00:00Z',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(FavouritesPage), findsOneWidget);
        expect(router.canPop(), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('comparison has a visible control and does not open the ad', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    final router = await _open(tester, fixture);
    final compare = find.byTooltip('Comparar').first;
    await _reveal(tester, compare);
    List<ListingCard> cards() =>
        tester.widgetList<ListingCard>(find.byType(ListingCard)).toList();
    final before = cards();
    expect(before.length, greaterThan(1));
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(fixture.compare.state, [interfaceListing(0).id]);
    // Only the picked card is rebuilt; the others keep their widgets.
    final after = cards();
    expect(after.first.selected, isTrue);
    expect(identical(after.first, before.first), isFalse);
    for (var i = 1; i < before.length && i < after.length; i++) {
      expect(identical(after[i], before[i]), isTrue, reason: 'card $i');
    }
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.deals);
    expect(find.text('Comparar (1)'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirar da comparação').first);
    await tester.pumpAndSettle();
    expect(fixture.compare.state, isEmpty);
    expect(find.text('Comparar (1)'), findsNothing);

    await tester.longPress(find.text('Matosinhos, a 8 km').first);
    await tester.pumpAndSettle();
    expect(fixture.compare.state, [interfaceListing(0).id]);
    await tester.longPress(find.text('Matosinhos, a 8 km').first);
    await tester.pumpAndSettle();
    expect(fixture.compare.state, isEmpty);

    await tester.tap(find.text('Matosinhos, a 8 km').first);
    await tester.pumpAndSettle();
    expect(find.byType(ListingDetailPage), findsOneWidget);
  });

  testWidgets('the labelled save action keeps the current criteria', (
    tester,
  ) async {
    final fixture = InterfaceFixture(emptySearches: true);
    await _open(tester, fixture);
    // Nothing chosen, nothing to save.
    expect(find.widgetWithText(TextButton, 'Guardar pesquisa'), findsNothing);
    await fixture.listings.applyFilters(
      const ListingFilters(activeOnly: false),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Guardar pesquisa'), findsNothing);
    await fixture.listings.applyFilters(const ListingFilters(maxPrice: 7000));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(TextButton, 'Guardar pesquisa');
    await _reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Até sete mil');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values.single.name, 'Até sete mil');
    expect(fixture.searchesRepository.values.single.filters.maxPrice, 7000);
    // Saved: nothing left to save, so the same search can't be saved twice.
    expect(find.widgetWithText(TextButton, 'Guardar pesquisa'), findsNothing);
    expect(
      find.widgetWithText(TextButton, 'Pesquisa guardada'),
      findsOneWidget,
    );
  });

  testWidgets('a saved search applied in Ofertas shows as saved', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture);
    await fixture.searches.load();
    await fixture.listings.applyFilters(
      fixture.searchesRepository.values.single.filters,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Guardar pesquisa'), findsNothing);
    expect(
      find.widgetWithText(TextButton, 'Pesquisa guardada'),
      findsOneWidget,
    );

    await fixture.listings.applyFilters(const ListingFilters(maxPrice: 7000));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Guardar pesquisa'), findsOneWidget);
  });

  testWidgets('sort labels and removable filters still drive the query', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture);
    await fixture.listings.applyFilters(
      const ListingFilters(maxPrice: 7000, minYear: 2022),
    );
    await tester.pumpAndSettle();

    final year = find.widgetWithText(InputChip, 'desde 2022');
    await _reveal(tester, year);
    await tester.tap(
      find.descendant(of: year, matching: find.byTooltip('Remover filtro')),
    );
    await tester.pumpAndSettle();
    expect(fixture.listings.state.filters.minYear, isNull);
    expect(fixture.listings.state.filters.maxPrice, 7000);

    await _reveal(tester, find.byTooltip('Ordenar'));
    await tester.tap(find.byTooltip('Ordenar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Preço mais baixo'),
        matching: find.byType(CheckedPopupMenuItem<ListingSort>),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.repository.lastSort, ListingSort.priceAsc);
    expect(find.text('Preço mais baixo'), findsOneWidget);
  });

  testWidgets('scrolling still loads the next page without duplicates', (
    tester,
  ) async {
    final fixture = InterfaceFixture(total: 45);
    await _open(tester, fixture);
    expect(find.text('40 anúncios carregados'), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -18000),
      10000,
    );
    await tester.pumpAndSettle();
    expect(fixture.repository.offsets, [0, 40]);
    expect(fixture.listings.state.listings, hasLength(45));
    expect(
      fixture.listings.state.listings.map((l) => l.id).toSet(),
      hasLength(45),
    );
    expect(fixture.listings.state.hasMore, isFalse);
  });

  testWidgets('an error retains its retry action', (tester) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture);
    fixture.repository.fail = true;
    await fixture.listings.load();
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as ofertas'), findsOneWidget);

    fixture.repository.fail = false;
    final retry = find.text('Tentar novamente');
    await _reveal(tester, retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byType(ListingCard), findsWidgets);
  });

  testWidgets('empty offers retain model onboarding', (tester) async {
    await _open(tester, InterfaceFixture(total: 0));
    expect(find.text('A próxima mota começa aqui.'), findsOneWidget);
    expect(find.text('Ainda não há ofertas'), findsOneWidget);
    expect(find.text('Escolher modelos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact offers error can still be scrolled and retried', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture, size: const Size(320, 480), textScale: 2);
    fixture.repository.fail = true;
    await fixture.listings.load();
    await tester.pumpAndSettle();
    final retry = find.text('Tentar novamente');
    await _reveal(tester, retry);
    fixture.repository.fail = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(fixture.repository.offsets, [0, 0]);
    expect(find.text('Não foi possível carregar as ofertas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved search title opens its results', (tester) async {
    final fixture = InterfaceFixture();
    final router = await _open(tester, fixture, location: AppRoutes.searches);
    expect(find.text('3 anúncios encontrados'), findsOneWidget);
    await tester.tap(find.text(fixture.searchesRepository.values.first.name!));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.deals);
    expect(fixture.listings.state.filters.maxPrice, 7000);
    expect(fixture.listings.state.filters.minYear, 2022);
  });

  testWidgets('saved search actions fit narrow screens with enlarged text', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(
      tester,
      fixture,
      location: AppRoutes.searches,
      size: const Size(320, 720),
      textScale: 2,
    );
    final options = find.byTooltip('Opções da pesquisa');
    await _reveal(tester, options);
    await tester.tap(options);
    await tester.pumpAndSettle();
    expect(find.text('Editar pesquisa'), findsOneWidget);
    expect(find.text('Eliminar pesquisa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Eliminar pesquisa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values, hasLength(1));
  });

  testWidgets('empty searches have one clear create action', (tester) async {
    await _open(
      tester,
      InterfaceFixture(emptySearches: true),
      location: AppRoutes.searches,
    );
    expect(find.text('Nova pesquisa'), findsOneWidget);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'saved search swipe editing ${fail ? 'reports failure' : 'saves'}',
      (tester) async {
        final fixture = InterfaceFixture();
        await _open(tester, fixture, location: AppRoutes.searches);
        final original = fixture.searchesRepository.values.single.name;
        await _swipe(tester, 'search-1', delete: false);
        expect(find.text('Editar pesquisa'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'A minha próxima mota',
        );
        fixture.searchesRepository.failWrites = fail;
        final save = find.widgetWithText(FilledButton, 'Guardar');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          fixture.searchesRepository.values.single.name,
          fail ? original : 'A minha próxima mota',
        );
        expect(
          find.text(
            fail
                ? 'Não foi possível atualizar a pesquisa'
                : 'Pesquisa atualizada',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('search-1')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancelled search swipes keep the card and can be used again', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture, location: AppRoutes.searches);
    final original = fixture.searchesRepository.values.single.name;
    await _swipe(tester, 'search-1', delete: false);
    await tester.enterText(find.byType(TextFormField), 'Não guardar');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values.single.name, original);
    await _swipe(tester, 'search-1', delete: true);
    expect(find.text('Eliminar pesquisa?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values, hasLength(1));
    expect(find.byKey(const ValueKey('search-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search swipe deletion preserves the other card and its actions',
    (tester) async {
      final fixture = InterfaceFixture();
      await fixture.searchesRepository.create(
        name: 'Outra pesquisa',
        filters: const ListingFilters(minYear: 2021),
      );
      await _open(tester, fixture, location: AppRoutes.searches);
      await _swipe(tester, 'search-1', delete: true);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(fixture.searchesRepository.values.single.id, 'search-2');
      expect(find.byKey(const ValueKey('search-1')), findsNothing);
      await _swipe(tester, 'search-2', delete: false);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Outra pesquisa',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed search swipe deletion keeps the search and shows why', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture, location: AppRoutes.searches);
    fixture.searchesRepository.failWrites = true;
    await _swipe(tester, 'search-1', delete: true);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(fixture.searchesRepository.values, hasLength(1));
    expect(find.byKey(const ValueKey('search-1')), findsOneWidget);
    expect(find.text('Não foi possível eliminar a pesquisa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final alerts in [false, true]) {
    testWidgets('a short ${alerts ? 'alert' : 'search'} swipe does nothing', (
      tester,
    ) async {
      final fixture = InterfaceFixture();
      await _open(
        tester,
        fixture,
        location: alerts ? AppRoutes.alerts : AppRoutes.searches,
      );
      await _swipe(
        tester,
        alerts ? 'alert-0' : 'search-1',
        delete: true,
        fraction: 0.15,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(fixture.alertsRepository.dismissed, isEmpty);
      expect(fixture.searchesRepository.values, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('alert swipe deletion clears the badge without erasing history', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture, location: AppRoutes.alerts);
    for (var i = 0; i < 3; i++) {
      await _swipe(tester, 'alert-$i', delete: true);
      expect(find.text('Eliminar alerta?'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('alert-$i')), findsNothing);
      expect(fixture.alerts.state.unreadCount, 2 - i);
      expect(fixture.alertsRepository.dismissed, contains('alert-$i'));
    }
    await fixture.alerts.load();
    await tester.pumpAndSettle();
    expect(find.text('Ainda não tem alertas'), findsOneWidget);
    expect(fixture.alertsRepository.values, hasLength(3));
    expect(fixture.searchesRepository.values, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled and failed alert swipes keep their unread notification',
    (tester) async {
      final fixture = InterfaceFixture();
      await _open(tester, fixture, location: AppRoutes.alerts);
      fixture.alertsRepository.failDismiss = true;
      await _swipe(tester, 'alert-0', delete: true);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fixture.alertsRepository.dismissed, isEmpty);
      await _swipe(tester, 'alert-0', delete: true);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível eliminar o alerta'), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-0')), findsOneWidget);
      expect(fixture.alerts.state.unreadCount, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a pending alert dismissal can finish after leaving the app', (
    tester,
  ) async {
    final saved = Completer<void>();
    final fixture = InterfaceFixture();
    fixture.alertsRepository.dismissDelay = saved.future;
    await _open(tester, fixture, location: AppRoutes.alerts);
    await _swipe(tester, 'alert-0', delete: true);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(fixture.alerts.state.unreadCount, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    saved.complete();
    await tester.pumpAndSettle();
    expect(fixture.alerts.state.unreadCount, 2);
    expect(fixture.alertsRepository.dismissed, contains('alert-0'));
    expect(tester.takeException(), isNull);
  });

  for (final menu in [false, true]) {
    testWidgets(
      'an alert can edit its source search by ${menu ? 'menu' : 'swipe'}',
      (tester) async {
        final fixture = InterfaceFixture();
        await _open(tester, fixture, location: AppRoutes.alerts);
        if (menu) {
          final options = find.descendant(
            of: find.byKey(const ValueKey('alert-0')),
            matching: find.byTooltip('Opções do alerta'),
          );
          await tester.ensureVisible(options);
          await tester.tap(options);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Editar pesquisa'));
          await tester.pumpAndSettle();
        } else {
          await _swipe(tester, 'alert-0', delete: false);
        }
        expect(find.text('Editar pesquisa'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          fixture.searchesRepository.values.single.name,
        );
        await tester.enterText(
          find.byType(TextFormField),
          'MT-07 para a garagem',
        );
        final save = find.widgetWithText(FilledButton, 'Guardar');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          fixture.searchesRepository.values.single.name,
          'MT-07 para a garagem',
        );
        expect(
          fixture.alerts.state.alerts
              .firstWhere((alert) => alert.id == 'alert-0')
              .searchName,
          'MT-07 para a garagem',
        );
        expect(find.textContaining('MT-07 para a garagem'), findsOneWidget);
        expect(fixture.alertsRepository.dismissed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'alerts without a search only expose deletion, including large text',
    (tester) async {
      final fixture = InterfaceFixture();
      await _open(
        tester,
        fixture,
        location: AppRoutes.alerts,
        size: const Size(320, 720),
        textScale: 2,
        dark: true,
      );
      await _swipe(tester, 'alert-1', delete: false);
      expect(find.byType(TextFormField), findsNothing);
      final options = find.descendant(
        of: find.byKey(const ValueKey('alert-1')),
        matching: find.byTooltip('Opções do alerta'),
      );
      await tester.ensureVisible(options);
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(find.text('Editar pesquisa'), findsNothing);
      await tester.tap(find.text('Eliminar alerta'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar alerta?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fixture.alertsRepository.dismissed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final offline in [false, true]) {
    testWidgets(
      'source editing reports a ${offline ? 'failed load' : 'deleted search'}',
      (tester) async {
        final fixture = InterfaceFixture();
        await _open(tester, fixture, location: AppRoutes.alerts);
        if (offline) {
          fixture.searchesRepository.failReads = true;
        } else {
          fixture.searchesRepository.values.clear();
        }
        await _swipe(tester, 'alert-0', delete: false);
        expect(find.byType(TextFormField), findsNothing);
        expect(
          find.text(
            offline
                ? 'Não foi possível carregar a pesquisa deste alerta'
                : 'A pesquisa deste alerta já não existe',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('alert-0')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('alerts remain readable and can all be marked read', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(
      tester,
      fixture,
      location: AppRoutes.alerts,
      size: const Size(320, 720),
      textScale: 2,
    );
    await _reveal(tester, find.text('3 alertas por ler'));
    expect(find.text('3 alertas por ler'), findsOneWidget);
    await tester.tap(find.byTooltip('Marcar todos como lidos'));
    await tester.pumpAndSettle();
    expect(fixture.alertsRepository.allRead, isTrue);
    expect(find.text('Tudo lido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening an alert marks it read and opens the correct ad', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture, location: AppRoutes.alerts);
    final title = find.text('Novo anúncio: Yamaha MT-07 · 2023');
    await _reveal(tester, title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(fixture.alertsRepository.markedRead, ['alert-0']);
    expect(
      tester
          .widget<ListingDetailPage>(find.byType(ListingDetailPage))
          .listingId,
      interfaceListing(0).id,
    );
  });

  testWidgets('navigation adapts between mobile, tablet and desktop', (
    tester,
  ) async {
    await _open(tester, InterfaceFixture());
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Pesquisas'),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('As suas pesquisas'), findsOneWidget);

    tester.view.physicalSize = const Size(900, 1000);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.text('As suas pesquisas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final admin in [false, true]) {
    testWidgets('Mais shows administration only to admins (admin: $admin)', (
      tester,
    ) async {
      await _open(
        tester,
        InterfaceFixture(signedIn: true, admin: admin),
        location: AppRoutes.more,
      );
      await _reveal(tester, find.text('Qualidade dos dados'));
      // To the end of the list, past the last section.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.text('Administração'), admin ? findsOneWidget : findsNothing);
      expect(
        find.text('Contas e convites'),
        admin ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('distance without a home asks for the home first', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture);
    Future<void> chooseNearest() async {
      await _reveal(tester, find.byTooltip('Ordenar'));
      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      expect(find.text('Indique primeiro a sua localidade'), findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: find.text('Mais perto'),
          matching: find.byType(CheckedPopupMenuItem<ListingSort>),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Leaving the town search keeps the order.
    await chooseNearest();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(fixture.listings.state.sort, isNot(ListingSort.nearest));

    // The distance filter is off and offers the same search.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ExpansionTile, 'Local e distância'));
    await tester.pumpAndSettle();
    expect(
      find.text('Indique a sua localidade para filtrar por distância'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Indicar a sua localidade'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();

    // A town found and picked is saved, then the order applies.
    await chooseNearest();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'por',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Porto'));
    await tester.pumpAndSettle();
    expect(fixture.home.place?.name, 'Porto');
    expect(fixture.repository.lastSort, ListingSort.nearest);

    await tester.tap(find.byTooltip('Ordenar'));
    await tester.pumpAndSettle();
    expect(find.text('Indique primeiro a sua localidade'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter sections open on a tap and say what is chosen', (
    tester,
  ) async {
    final fixture = InterfaceFixture();
    await _open(tester, fixture);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Filtros'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'MT-07'), findsNothing);

    await tester.tap(find.widgetWithText(ExpansionTile, 'Modelos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'MT-07'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpansionTile).first,
        matching: find.text('MT-07'),
      ),
      findsWidgets,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(fixture.listings.state.filters.motorcycleIds, ['mt07']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings stay navigable with large text on a small phone', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      location: AppRoutes.more,
      size: const Size(320, 720),
      textScale: 2,
    );
    expect(find.text('A sua garagem'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Modelos acompanhados'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Modelos acompanhados'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qualidade dos dados'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop rail and results accommodate enlarged text', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      size: const Size(1440, 1000),
      textScale: 2,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(find.byType(SliverGrid), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 720), const Size(1440, 1000)]) {
    testWidgets('listing detail and section tabs fit $size', (tester) async {
      await _open(
        tester,
        InterfaceFixture(),
        size: size,
        location: AppRoutes.listingDetail(interfaceListing(0).id),
      );
      final photo = tester.getRect(find.byType(PhotoGallery));
      final headline = tester.getRect(find.text('Yamaha MT-07'));
      if (size.width >= 840) {
        expect(headline.left, greaterThan(photo.right));
      } else {
        expect(headline.top, greaterThan(photo.bottom));
      }
      expect(find.text('Ver no Standvirtual'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TabBar),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.tabs.cast<Tab>().map((tab) => tab.text), [
        'Avaliação',
        'Detalhes',
        'Mercado',
        'Negociar',
      ]);
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('A mota'), findsOneWidget);
      await tester.tap(find.text('Avaliação'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching detail tabs preserves an expanded description', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      location: AppRoutes.listingDetail(interfaceListing(0).id),
    );
    await _reveal(tester, find.byType(TabBar));
    await tester.tap(find.text('Detalhes'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Mostrar tudo'));
    await tester.tap(find.text('Mostrar tudo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TabBar),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrar menos'), findsOneWidget);
    await tester.tap(find.text('Avaliação'));
    await tester.pumpAndSettle();
  });

  testWidgets('the bar names the bike once its heading scrolls away (F.4)', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      location: AppRoutes.listingDetail(interfaceListing(0).id),
    );
    final bar = find.descendant(
      of: find.byType(ListingDetailPage),
      matching: find.byType(AppBar),
    );
    final plain = find.descendant(of: bar, matching: find.text('O anúncio'));
    final compact = find.descendant(
      of: bar,
      matching: find.textContaining('Yamaha MT-07\n2023 · '),
    );
    final list = find.byType(Scrollable).first;
    // Negociar is long enough to scroll the heading well away.
    await _reveal(tester, find.byType(TabBar));
    await tester.tap(find.text('Negociar'));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(plain, findsOneWidget);
    expect(compact, findsNothing);

    final page = find.byType(ListView).first;
    final heading = find
        .descendant(of: page, matching: find.text('Yamaha MT-07'))
        .first;
    final past = tester.getBottomLeft(heading).dy - tester.getTopLeft(page).dy;
    final position = tester.state<ScrollableState>(list).position;
    expect(
      position.maxScrollExtent,
      greaterThan(past + 40),
      reason: 'the page must scroll past its heading',
    );

    // Just past the heading (the drag loses its touch slop first).
    await tester.drag(list, Offset(0, -(past + 40)));
    await tester.pumpAndSettle();
    expect(compact, findsOneWidget);
    expect(plain, findsNothing);

    // A long jump lets go of the heading's item: still named.
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(compact, findsOneWidget);

    await tester.drag(list, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(plain, findsOneWidget);
    expect(compact, findsNothing);

    // The page remembers the part: leave it on Avaliação.
    await _reveal(tester, find.byType(TabBar));
    await tester.tap(find.text('Avaliação'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sharing an ad copies its link where there is no share sheet', (
    tester,
  ) async {
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final listing = interfaceListing(0);
    await _open(
      tester,
      InterfaceFixture(),
      size: const Size(320, 720),
      textScale: 2,
      location: AppRoutes.listingDetail(listing.id),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Partilhar o anúncio'));
    await tester.pumpAndSettle();
    expect(copied, startsWith('Yamaha MT-07 · 2023 · '));
    expect(copied, contains('Anúncio original: ${listing.url}'));
    expect(copied, endsWith('/#${AppRoutes.listingDetail(listing.id)}'));
    expect(find.text('Link copiado. Cole-o numa mensagem.'), findsOneWidget);
  });

  testWidgets('an ad opened from a list opens on the part last read (F.4)', (
    tester,
  ) async {
    final router = await _open(
      tester,
      InterfaceFixture(),
      location: AppRoutes.listingDetail(interfaceListing(0).id),
    );
    int section() =>
        DefaultTabController.of(tester.element(find.byType(TabBar))).index;
    await _reveal(tester, find.byType(TabBar));
    expect(section(), 0);
    await tester.tap(find.text('Negociar'));
    await tester.pumpAndSettle();
    expect(section(), 3);

    router.go(AppRoutes.deals);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListingCard).first);
    await tester.pumpAndSettle();
    await _reveal(tester, find.byType(TabBar));
    expect(section(), 3, reason: 'went on from Ofertas');

    // A notification, an alert or a shared link: the ad from the start.
    router.go(AppRoutes.listingDetail(interfaceListing(2).id));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byType(TabBar));
    expect(section(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying abroad stays one closed line on a listing (F.4)', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      location: AppRoutes.listingDetail(interfaceListing(0).id),
    );
    await _reveal(tester, find.byType(TabBar));
    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    final title = find.text('E se a comprar no estrangeiro?');
    await _reveal(tester, title);
    expect(
      find.text(
        'Some o ISV, a legalização e o transporte a um preço de Espanha, '
        'França ou Alemanha.',
      ),
      findsOneWidget,
    );
    expect(find.text('Preço lá'), findsNothing);
    await tester.tap(title);
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Preço lá'));
    expect(find.text('Preço lá'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The part last read outlives the page: leave Avaliação for the tests
    // that open ads from Ofertas.
    await tester.scrollUntilVisible(
      find.byType(TabBar),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Avaliação'));
    await tester.pumpAndSettle();
  });

  testWidgets('the detail verdict remains readable with enlarged text', (
    tester,
  ) async {
    await _open(
      tester,
      InterfaceFixture(),
      size: const Size(320, 720),
      textScale: 2,
      location: AppRoutes.listingDetail(interfaceListing(0).id),
    );
    await _reveal(tester, find.text('10/100'));
    expect(tester.takeException(), isNull);
    expect(find.text('10/100'), findsOneWidget);
  });

  for (final score in [9, 92, 100]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('detail score $score is centered at ${scale}x text', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: AppLanguage.portuguese.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: appLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [DealScoreBadge(score: score, large: true)],
                  ),
                ),
              ),
            ),
          ),
        );
        final badge = tester.getRect(find.byType(DealScoreBadge));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('$score'),
        );
        final painter =
            TextPainter(
              text: paragraph.text,
              textAlign: paragraph.textAlign,
              textDirection: paragraph.textDirection,
              textScaler: TextScaler.linear(scale),
            )..layout(
              minWidth: paragraph.size.width,
              maxWidth: paragraph.size.width,
            );
        addTearDown(painter.dispose);
        final line = painter.computeLineMetrics().single;
        final center = paragraph.localToGlobal(
          Offset(
            line.left + line.width / 2,
            line.baseline - line.ascent + line.height / 2,
          ),
        );

        expect(center.dx, closeTo(badge.center.dx, 0.5));
        expect(center.dy, closeTo(badge.center.dy, 0.5));
      });
    }
  }

  testWidgets('fullscreen affordance opens the photo currently selected', (
    tester,
  ) async {
    _screen(tester, const Size(390, 844));
    final listingId = interfaceListing(0).id;
    const images = [
      'https://example.test/one.jpg',
      'https://example.test/two.jpg',
    ];
    PhotoViewerArgs? received;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PhotoGallery(listingId: listingId, images: images),
          ),
        ),
        GoRoute(
          path: AppRoutes.listingPhotos(listingId),
          builder: (_, state) {
            received = PhotoViewerArgs.fromExtra(state.extra);
            return const Scaffold(body: Text('Fotografias'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(interfaceApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Foto seguinte'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Ampliar fotografias'));
    await tester.pumpAndSettle();
    expect(received?.index, 1);
    expect(received?.images, images);
    expect(find.text('Fotografias'), findsOneWidget);
  });

  testWidgets('empty states scroll instead of overflowing large text', (
    tester,
  ) async {
    _screen(tester, const Size(320, 240));
    var acted = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLanguage.portuguese.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: StateMessage(
            icon: Icons.search_off,
            title: 'Ainda não há anúncios',
            message: 'Escolha os modelos que quer acompanhar.',
            actionLabel: 'Escolher modelos',
            onAction: () => acted = true,
          ),
        ),
      ),
    );
    final action = find.text('Escolher modelos');
    await _reveal(tester, action);
    await tester.tap(action);
    expect(acted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section headings can wrap without a fixed-height clip', (
    tester,
  ) async {
    _screen(tester, const Size(320, 720));
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLanguage.portuguese.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appLocales,
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              children: const [
                SectionCard(
                  title: 'Comparação com uma mota nova',
                  children: [Text('Uma referência para a sua decisão.')],
                ),
                DealScoreBadge(score: 100, large: true),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
