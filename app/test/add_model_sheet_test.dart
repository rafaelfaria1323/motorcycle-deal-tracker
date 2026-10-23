import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/site_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/catalog_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/add_model_sheet.dart';

import 'support/interface_fixture.dart';

class _Catalog extends Fake implements CatalogRepository {
  List<SiteMake> makes = const [SiteMake(id: 'honda', name: 'Honda', ads: 32)];
  bool failMakes = false;
  bool failModels = false;
  Completer<List<SiteMake>>? pendingMakes;

  @override
  Future<List<SiteMake>> getSiteMakes() async {
    if (failMakes) throw StateError('unavailable');
    return pendingMakes?.future ?? Future.value(makes);
  }

  @override
  Future<List<SiteModel>> getSiteModels(String makeId) async {
    if (failModels) throw StateError('unavailable');
    return const [
      SiteModel(
        source: 'standvirtual',
        makeId: 'honda',
        id: 'forza',
        name: 'Forza',
        ads: 32,
      ),
    ];
  }
}

void main() {
  setUpAll(loadInterfaceFonts);

  Future<void> open(
    WidgetTester tester,
    _Catalog repository,
    ValueChanged<NewModel?> onResult, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  onResult(await showAddModelSheet(context, repository)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextField, label);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Adicionar');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> pickBrand(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownMenu<SiteMake>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Honda').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a picked model includes both sources without exposing URLs', (
    tester,
  ) async {
    NewModel? result;
    await open(tester, _Catalog(), (value) => result = value);
    await pickBrand(tester);
    await tester.tap(find.byType(DropdownMenu<SiteModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forza').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('OLX e no Standvirtual'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('só o Standvirtual'), findsNothing);
    expect(find.textContaining('32 anúncios'), findsNothing);
    await enter(tester, 'Cilindrada (opcional)', '350');
    await enter(tester, 'Desde o ano', '2022');
    await submit(tester);

    expect(result?.brand, 'Honda');
    expect(result?.model, 'Forza 350');
    expect(result?.engineCcMin, 315);
    expect(result?.engineCcMax, 385);
    expect(
      result?.standvirtualSearch,
      'https://www.standvirtual.com/motos/honda/forza/q-350',
    );
    expect(result?.minYear, 2022);
  });

  testWidgets('manual names need no copied addresses or aliases', (
    tester,
  ) async {
    NewModel? result;
    await open(tester, _Catalog()..makes = [], (value) => result = value);

    expect(find.text('Pesquisa no OLX'), findsNothing);
    expect(find.textContaining('Pesquisa no Standvirtual'), findsNothing);
    await enter(tester, 'Marca', ' Honda ');
    await enter(tester, 'Modelo', 'ADV');
    await enter(tester, 'Cilindrada (opcional)', '350');
    await enter(tester, 'Desde o ano', '2024');
    await submit(tester);

    expect(result?.brand, 'Honda');
    expect(result?.model, 'ADV 350');
    expect(result?.engineCcMin, 315);
    expect(result?.engineCcMax, 385);
    expect(result?.olxSearch, isNull);
    expect(result?.standvirtualSearch, isNull);
    expect(result?.aliases, isEmpty);
  });

  testWidgets('catalog failures are visible and manual entry still works', (
    tester,
  ) async {
    NewModel? result;
    await open(tester, _Catalog()..failMakes = true, (value) => result = value);

    expect(
      find.textContaining('Não foi possível carregar as marcas'),
      findsOneWidget,
    );
    await enter(tester, 'Marca', 'Norton');
    await enter(tester, 'Modelo', 'V4 SV');
    await submit(tester);
    expect(result?.model, 'V4 SV');
  });

  testWidgets('a model-list failure keeps the chosen brand for manual entry', (
    tester,
  ) async {
    NewModel? result;
    await open(
      tester,
      _Catalog()..failModels = true,
      (value) => result = value,
    );
    await pickBrand(tester);

    expect(
      find.textContaining('Não foi possível carregar os modelos'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Escrever à mão'));
    await tester.pump();
    await tester.tap(find.text('Escrever à mão'));
    await tester.pumpAndSettle();
    await enter(tester, 'Modelo', 'CB500F');
    await submit(tester);
    expect(result?.brand, 'Honda');
    expect(result?.model, 'CB500F');
  });

  testWidgets('suggestions never block manual entry while loading', (
    tester,
  ) async {
    final makes = Completer<List<SiteMake>>();
    NewModel? result;
    await open(
      tester,
      _Catalog()..pendingMakes = makes,
      (value) => result = value,
    );

    await tester.tap(find.text('Escrever à mão'));
    await tester.pumpAndSettle();
    await enter(tester, 'Marca', 'Norton');
    await enter(tester, 'Modelo', 'Atlas');
    await submit(tester);
    makes.complete([]);
    await tester.pump();
    expect(result?.model, 'Atlas');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the compact form supports enlarged text and optional aliases', (
    tester,
  ) async {
    NewModel? result;
    await open(
      tester,
      _Catalog()..makes = [],
      (value) => result = value,
      textScale: 2,
    );
    await enter(tester, 'Marca', 'Kawasaki');
    await enter(tester, 'Modelo', 'Z650');
    await tester.ensureVisible(find.text('Outros nomes do modelo'));
    await tester.pump();
    await tester.tap(find.text('Outros nomes do modelo'));
    await tester.pumpAndSettle();
    await enter(tester, 'Outros nomes (opcional)', 'Z 650, Z-650');
    await submit(tester);

    expect(result?.aliases, ['Z 650', 'Z-650']);
    expect(tester.takeException(), isNull);
  });
}
