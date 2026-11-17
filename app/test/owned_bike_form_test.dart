import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/owned_bike.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/widgets/owned_bike_form.dart';

import '../integration_test/support/interface_fixture.dart';

// "A minha mota" with any model (N.120): besides the followed models, the
// form offers "Outra marca ou modelo…", and the model picked there is the
// bike's.
void main() {
  setUpAll(loadInterfaceFonts);

  Future<void> open(
    WidgetTester tester, {
    required List<OwnedBikeModel> models,
    required Future<OwnedBikeModel?> Function() pickOther,
    required ValueChanged<OwnedBikeDraft?> onResult,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLanguage.portuguese.locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showOwnedBikeForm(
                  context,
                  initial: null,
                  models: models,
                  pickOther: pickOther,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseOther(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra marca ou modelo…').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a model nobody follows is picked and saved', (tester) async {
    OwnedBikeDraft? saved;
    var asked = 0;
    await open(
      tester,
      models: const [],
      pickOther: () async {
        asked++;
        return (id: 'versys', name: 'Kawasaki Versys 650');
      },
      onResult: (bike) => saved = bike,
    );

    await chooseOther(tester);
    expect(asked, 1);
    expect(find.text('Kawasaki Versys 650'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ano'), '2019');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved?.motorcycleId, 'versys');
    expect(saved?.year, 2019);
  });

  testWidgets('a cancelled pick keeps the model chosen before', (
    tester,
  ) async {
    OwnedBikeDraft? saved;
    await open(
      tester,
      models: const [(id: 'mt07', name: 'Yamaha MT-07')],
      pickOther: () async => null,
      onResult: (bike) => saved = bike,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yamaha MT-07').last);
    await tester.pumpAndSettle();
    await chooseOther(tester);
    expect(find.text('Yamaha MT-07'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ano'), '2021');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved?.motorcycleId, 'mt07');
  });
}
