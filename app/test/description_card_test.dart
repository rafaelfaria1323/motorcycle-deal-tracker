import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/widgets/description_card.dart';

import '../integration_test/support/interface_fixture.dart';

// The ad's own title shows above its description (N.122): the A2 and
// extras rules read it too, so a reason found only there can be seen.
void main() {
  setUpAll(loadInterfaceFonts);

  Future<void> pump(WidgetTester tester, DescriptionCard card) =>
      tester.pumpWidget(
        MaterialApp(
          locale: AppLanguage.portuguese.locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appLocales,
          theme: AppTheme.light,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      );

  testWidgets('shows the title above the description', (tester) async {
    await pump(
      tester,
      const DescriptionCard(
        title: 'MT-07 35kW',
        description: 'Mota impecável.',
      ),
    );
    expect(find.text('Título do anúncio'), findsOneWidget);
    expect(find.text('MT-07 35kW'), findsOneWidget);
    expect(find.text('Mota impecável.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('MT-07 35kW')).dy,
      lessThan(tester.getTopLeft(find.text('Mota impecável.')).dy),
    );
  });

  testWidgets('a version with its own label, without a description', (
    tester,
  ) async {
    await pump(
      tester,
      const DescriptionCard(title: 'ABS 35kW', titleLabel: 'Versão'),
    );
    expect(find.text('Versão'), findsOneWidget);
    expect(find.text('ABS 35kW'), findsOneWidget);
    expect(find.text('Mostrar tudo'), findsNothing);
  });

  testWidgets('no title: only the description', (tester) async {
    await pump(tester, const DescriptionCard(description: 'Mota impecável.'));
    expect(find.text('Título do anúncio'), findsNothing);
    expect(find.text('Mota impecável.'), findsOneWidget);
  });
}
