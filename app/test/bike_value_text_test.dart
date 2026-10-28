import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_value_request.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/bike_value_text.dart';

MarketBehaviour market({
  int gone = 0,
  int? toGone,
  int priced = 0,
  double? drop,
}) => MarketBehaviour(
  liveCount: 12,
  goneCount: gone,
  pricedCount: priced,
  droppedCount: 3,
  medianDaysToGone: toGone,
  medianDropPct: drop,
);

const value = BikeValue(
  comparableCount: 8,
  estimate: 6320,
  low: 6000,
  high: 6600,
);

String price(double amount) => Formatters.price(amount);

void main() {
  group('askingRoom', () {
    test('is the default without enough priced listings', () {
      expect(askingRoom(null), defaultAskingRoom);
      expect(askingRoom(market(priced: 4, drop: 7)), defaultAskingRoom);
      expect(askingRoom(market(priced: 5)), defaultAskingRoom);
    });

    test("follows the model's typical drop within the limits", () {
      expect(askingRoom(market(priced: 5, drop: 6)), closeTo(0.06, 1e-9));
      expect(askingRoom(market(priced: 5, drop: 1)), minAskingRoom);
      expect(askingRoom(market(priced: 5, drop: 20)), maxAskingRoom);
    });
  });

  test('too few comparables give only a line saying so', () {
    final lines = bikeValueLines(
      const BikeValue(
        comparableCount: 2,
        estimate: 6000,
        low: 5900,
        high: 6100,
      ),
      null,
    );
    expect(lines, hasLength(1));
    expect(lines.single.kind, BikeValueLineKind.estimate);
    expect(lines.single.text, contains('2 comparáveis; são precisos 3'));

    final none = bikeValueLines(const BikeValue(comparableCount: 0), null);
    expect(none.single.text, contains('nenhum comparável'));
  });

  test('the value, the price to ask, the time and the trade-in', () {
    final lines = bikeValueLines(
      value,
      market(gone: 6, toGone: 21, priced: 10, drop: 6),
    );
    expect([for (final l in lines) l.kind], BikeValueLineKind.values);
    expect(
      lines[0].text,
      'Valor de mercado: ${price(6320)} (a maioria entre ${price(6000)} e '
      '${price(6600)}; 8 anúncios)',
    );
    // 6320 x 1.06 = 6699.2, rounded down to 50 €.
    expect(
      lines[1].text,
      'Para vender, peça cerca de ${price(6650)}: os vendedores deste '
      'modelo costumam baixar 6 %',
    );
    expect(lines[2].text, contains('21 dias (6 anúncios)'));
    // 6320 x 0.8 = 5056.
    expect(lines[3].text, contains('cerca de ${price(5050)} ou menos'));
  });

  test('without the model figures the default room and few-data time', () {
    final lines = bikeValueLines(value, null);
    // 6320 x 1.05 = 6636.
    expect(
      lines[1].text,
      'Para vender, peça cerca de ${price(6600)}: 5 % acima do valor, '
      'para negociar',
    );
    expect(lines[2].text, contains('ainda poucos dados'));
  });

  test('English', () {
    final lines = bikeValueLines(value, null, language: AppLanguage.english);
    expect(lines[0].text, startsWith('Market value: '));
    expect(lines[1].text, contains('room to negotiate'));
  });

  group('bikeValueRequestLine', () {
    final asked = BikeValueRequest(
      id: 'r1',
      motorcycleId: 'm1',
      brand: 'Kawasaki',
      model: 'Z650',
      year: 2019,
      mileage: 30000,
      requestedAt: DateTime.utc(2026, 10, 28, 9),
    );

    test('year, mileage and whether it still waits', () {
      expect(
        bikeValueRequestLine(asked),
        '2019 · ${Formatters.mileage(30000)} · À espera da recolha',
      );
    });

    test('answered, without mileage, in English', () {
      final answered = BikeValueRequest(
        id: 'r2',
        motorcycleId: 'm1',
        brand: 'Kawasaki',
        model: 'Z650',
        year: 2019,
        requestedAt: DateTime.utc(2026, 10, 28, 9),
        answeredAt: DateTime.utc(2026, 10, 28, 10),
      );
      expect(
        bikeValueRequestLine(answered, language: AppLanguage.english),
        '2019 · Value ready',
      );
    });
  });
}
