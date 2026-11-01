import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_condition.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value_request.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/exit_price.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/bike_value_text.dart';

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
    expect(
      [for (final l in lines) l.kind],
      [
        BikeValueLineKind.estimate,
        BikeValueLineKind.asking,
        BikeValueLineKind.time,
        BikeValueLineKind.tradeIn,
      ],
    );
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

  test('what the gone ads left at, after the value, with the condition', () {
    const exit = ExitPrice(goneCount: 6, median: 6000);
    final lines = bikeValueLines(
      value,
      null,
      condition: const BikeCondition(damage: BikeDamage.accident),
      exit: exit,
    );
    expect([for (final l in lines) l.kind].take(3), [
      BikeValueLineKind.estimate,
      BikeValueLineKind.condition,
      BikeValueLineKind.exit,
    ]);
    // 6000 x 0.85.
    expect(
      lines[2].text,
      startsWith('Saíram do mercado por cerca de ${price(5100)}: '),
    );

    // Too few gone ads: no line.
    expect(
      bikeValueLines(
        value,
        null,
        exit: const ExitPrice(goneCount: 4, median: 6000),
      ),
      bikeValueLines(value, null),
    );
  });

  test('English', () {
    final lines = bikeValueLines(value, null, language: AppLanguage.english);
    expect(lines[0].text, startsWith('Market value: '));
    expect(lines[1].text, contains('room to negotiate'));
  });

  group('condition', () {
    test('nothing known or usual changes nothing', () {
      const usual = BikeCondition(
        owners: BikeOwners.two,
        serviceBook: BikeServiceBook.yes,
      );
      expect(conditionFactors(const BikeCondition()), isEmpty);
      expect(conditionFactors(usual), isEmpty);
      expect(conditionShare(usual), 0);
      expect(
        bikeValueLines(value, null, condition: usual),
        bikeValueLines(value, null),
      );
    });

    test('each answer brings its factor, in order', () {
      const worst = BikeCondition(
        damage: BikeDamage.accident,
        owners: BikeOwners.threeOrMore,
        serviceBook: BikeServiceBook.no,
      );
      expect(conditionFactors(worst), [
        ConditionFactor.accident,
        ConditionFactor.manyOwners,
        ConditionFactor.noServiceBook,
      ]);
      expect(conditionShare(worst), closeTo(-0.25, 1e-9));
      const best = BikeCondition(owners: BikeOwners.one, warranty: true);
      expect(conditionFactors(best), [
        ConditionFactor.firstOwner,
        ConditionFactor.warranty,
      ]);
      expect(conditionShare(best), closeTo(0.06, 1e-9));
      expect(
        conditionFactors(const BikeCondition(damage: BikeDamage.dropped)),
        [ConditionFactor.dropped],
      );
    });

    test('adjusts the value, its range, the asking price and trade-in', () {
      // Dropped (-5 %) and first owner (+3 %): x0.98.
      final lines = bikeValueLines(
        value,
        null,
        condition: const BikeCondition(
          damage: BikeDamage.dropped,
          owners: BikeOwners.one,
        ),
      );
      expect(
        [for (final l in lines) l.kind],
        [
          for (final kind in BikeValueLineKind.values)
            if (kind != BikeValueLineKind.exit) kind,
        ],
      );
      // 6320 x 0.98 = 6193.6; 6000 -> 5880; 6600 -> 6468.
      expect(
        lines[0].text,
        'Valor de mercado: ${price(6193.6)} (a maioria entre ${price(5880)} '
        'e ${price(6468)}; 8 anúncios)',
      );
      expect(
        lines[1].text,
        'Ajustado ao estado: queda −5 %, primeiro dono +3 % (total −2 %)',
      );
      // 6193.6 x 1.05 = 6503.28 -> 6500; x 0.8 = 4954.88 -> 4950.
      expect(lines[2].text, contains(price(6500)));
      expect(lines[4].text, contains('cerca de ${price(4950)} ou menos'));
    });

    test('in English; few comparables still say only that', () {
      final lines = bikeValueLines(
        value,
        null,
        condition: const BikeCondition(warranty: true),
        language: AppLanguage.english,
      );
      expect(
        lines[1].text,
        'Adjusted for condition: under warranty +3% (total +3%)',
      );
      expect(
        bikeValueLines(
          const BikeValue(comparableCount: 2, estimate: 6000),
          null,
          condition: const BikeCondition(damage: BikeDamage.accident),
        ),
        hasLength(1),
      );
    });
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
