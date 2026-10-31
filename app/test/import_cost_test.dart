import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/import_cost.dart';

void main() {
  group('isvFor', () {
    test('follows Tabela C, nothing under 120 cc', () {
      expect(isvFor(50), 0);
      expect(isvFor(119), 0);
      expect(isvFor(120), 73.78);
      expect(isvFor(250), 73.78);
      expect(isvFor(251), 91.63);
      expect(isvFor(321), 91.63);
      expect(isvFor(471), 122.57);
      expect(isvFor(689), 184.45);
      expect(isvFor(750), 184.45);
      expect(isvFor(751), 245.14);
      expect(isvFor(998), 245.14);
    });
  });

  group('importCost', () {
    test('adds the ISV, the legalisation and the usual transport', () {
      final cost = importCost(
        price: 5000,
        engineCc: 689,
        country: ImportCountry.germany,
      );
      expect(cost.price, 5000);
      expect(cost.isv, 184.45);
      expect(cost.legalisation, 225);
      expect(cost.transport, 700);
      expect(cost.total, closeTo(6109.45, 1e-9));
    });

    test("a quote replaces the country's transport", () {
      final cost = importCost(
        price: 4000,
        engineCc: 300,
        country: ImportCountry.spain,
        transport: 200,
      );
      expect(cost.transport, 200);
      expect(cost.total, closeTo(4000 + 91.63 + 225 + 200, 1e-9));
    });

    test('the usual transport grows with the distance', () {
      expect(ImportCountry.spain.transport, 350);
      expect(ImportCountry.france.transport, 550);
      expect(ImportCountry.germany.transport, 700);
    });
  });

  group('mayBeNewForVat', () {
    final now = DateTime(2026, 10, 29);

    test('a bike of this year or the last with few or unknown km', () {
      expect(mayBeNewForVat(year: 2026, mileage: 0, now: now), isTrue);
      expect(mayBeNewForVat(year: 2025, mileage: 6000, now: now), isTrue);
      expect(mayBeNewForVat(year: 2026, now: now), isTrue);
    });

    test('older or further driven is used', () {
      expect(mayBeNewForVat(year: 2024, mileage: 100, now: now), isFalse);
      expect(mayBeNewForVat(year: 2026, mileage: 6001, now: now), isFalse);
      expect(mayBeNewForVat(year: 2024, now: now), isFalse);
    });
  });

  test('parseWholeAmount takes separators and the euro sign', () {
    expect(parseWholeAmount('5400'), 5400);
    expect(parseWholeAmount(' 5 400 '), 5400);
    expect(parseWholeAmount('5.400 €'), 5400);
    expect(parseWholeAmount(''), isNull);
    expect(parseWholeAmount('5,5'), isNull);
    expect(parseWholeAmount('-3'), isNull);
    expect(parseWholeAmount('abc'), isNull);
  });
}
