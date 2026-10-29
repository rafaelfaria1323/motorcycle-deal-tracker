import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_condition.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/bike_value_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/import_cost.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/import_cost_text.dart';

String price(double amount) => Formatters.price(amount);

void main() {
  final now = DateTime(2026, 10, 29);
  final cost = importCost(
    price: 5000,
    engineCc: 689,
    country: ImportCountry.germany,
  );

  test('the cost here, the saving against the estimate', () {
    final lines = importCostLines(
      cost,
      estimate: 7000,
      year: 2021,
      mileage: 20000,
      now: now,
    );
    expect(lines.map((l) => l.kind), [
      ImportLineKind.cost,
      ImportLineKind.comparison,
    ]);
    expect(
      lines[0].text,
      'Cá na estrada por ${price(cost.total)}: ${price(5000)} + '
      'ISV ${price(184.45)} + legalização ${price(225)} + '
      'transporte ${price(700)}',
    );
    expect(
      lines[1].text,
      'Cá, uma igual vale cerca de ${price(7000)}: poupa '
      '${price(7000 - cost.total)} '
      '(${Formatters.percent((7000 - cost.total) / 7000 * 100)})',
    );
  });

  test('dearer than here', () {
    final lines = importCostLines(
      cost,
      estimate: 6000,
      year: 2021,
      mileage: 20000,
      now: now,
    );
    expect(
      lines[1].text,
      'Cá, uma igual vale cerca de ${price(6000)}: trazê-la sai '
      '${price(cost.total - 6000)} mais caro',
    );
  });

  test('no estimate; a nearly new bike warns of the VAT', () {
    final lines = importCostLines(
      cost,
      estimate: null,
      year: 2026,
      mileage: 900,
      now: now,
    );
    expect(lines.map((l) => l.kind), [
      ImportLineKind.cost,
      ImportLineKind.comparison,
      ImportLineKind.vat,
    ]);
    expect(lines[1].text, contains('poucos anúncios'));
    expect(lines[2].text, contains('IVA'));
  });

  test("against a listing's asking price; no year, no VAT line", () {
    final cheaper = importCostLines(
      cost,
      estimate: 7000,
      year: null,
      mileage: null,
      now: now,
      against: ImportComparison.listing,
    );
    expect(cheaper.map((l) => l.kind), [
      ImportLineKind.cost,
      ImportLineKind.comparison,
    ]);
    expect(
      cheaper[1].text,
      'Este anúncio pede ${price(7000)}: trazê-la poupa '
      '${price(7000 - cost.total)} '
      '(${Formatters.percent((7000 - cost.total) / 7000 * 100)})',
    );
    final dearer = importCostLines(
      cost,
      estimate: 6000,
      year: 2021,
      mileage: 20000,
      now: now,
      against: ImportComparison.listing,
      language: AppLanguage.english,
    );
    expect(
      dearer[1].text,
      'This listing asks ${Formatters.price(6000, language: AppLanguage.english)}: '
      'bringing it costs '
      '${Formatters.price(cost.total - 6000, language: AppLanguage.english)} more',
    );
  });

  test('English, and the note', () {
    final lines = importCostLines(
      cost,
      estimate: 6000,
      year: 2021,
      mileage: 20000,
      now: now,
      language: AppLanguage.english,
    );
    expect(lines[0].text, startsWith('On the road here for '));
    expect(lines[1].text, contains('costs'));
    expect(importCostNote(), contains('2026'));
    expect(
      importCostNote(language: AppLanguage.english),
      startsWith('Rules of thumb for 2026'),
    );
  });

  test('conditionEstimate adjusts the value, none with few listings', () {
    const value = BikeValue(comparableCount: 8, estimate: 6000);
    expect(conditionEstimate(value), 6000);
    expect(
      conditionEstimate(
        value,
        const BikeCondition(damage: BikeDamage.accident),
      ),
      closeTo(5100, 1e-9),
    );
    expect(
      conditionEstimate(const BikeValue(comparableCount: 2, estimate: 6000)),
      isNull,
    );
    expect(conditionEstimate(const BikeValue(comparableCount: 8)), isNull);
  });
}
