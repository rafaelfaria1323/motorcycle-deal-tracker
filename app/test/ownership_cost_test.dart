import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/ownership_settings.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/ownership_cost.dart';

void main() {
  group('iucPerYear', () {
    test('follows the category E bands', () {
      expect(iucPerYear(engineCc: 695, year: 2021), 63.62);
      expect(iucPerYear(engineCc: 750, year: 2021), 63.62);
      expect(iucPerYear(engineCc: 751, year: 2021), 138.15);
      expect(iucPerYear(engineCc: 998, year: 2021), 138.15);
      expect(iucPerYear(engineCc: 470, year: 2021), 21.18);
      expect(iucPerYear(engineCc: 351, year: 2021), 21.18);
    });

    test('nothing to pay under 10 € (125 to 350 cc)', () {
      expect(iucPerYear(engineCc: 125, year: 2021), 0);
      expect(iucPerYear(engineCc: 321, year: 2021), 0);
      expect(iucPerYear(engineCc: 50, year: 2021), 0);
    });

    test('unknown without an engine size or before 1997', () {
      expect(iucPerYear(engineCc: null, year: 2021), isNull);
      expect(iucPerYear(engineCc: 695, year: 1996), isNull);
      expect(iucPerYear(engineCc: 695, year: 1997), 63.62);
      expect(iucPerYear(engineCc: 695), 63.62);
    });
  });

  test('running costs by engine size', () {
    expect(runningCostsFor(125), same(smallBikeCosts));
    expect(runningCostsFor(400), same(smallBikeCosts));
    expect(runningCostsFor(401), same(middleBikeCosts));
    expect(runningCostsFor(800), same(middleBikeCosts));
    expect(runningCostsFor(801), same(largeBikeCosts));
    expect(runningCostsFor(null), same(middleBikeCosts));
  });

  group('ownershipCost', () {
    test('an MT-07 with the defaults and the general rates', () {
      final c = ownershipCost(
        price: 6000,
        settings: const OwnershipSettings(),
        engineCc: 695,
        year: 2021,
      )!;
      expect(c.iuc, 63.62);
      expect(c.insurance, isNull);
      expect(c.tyres, 150); // half a 300 € set at 5 000 of 10 000 km
      expect(c.services, 180); // one a year
      expect(c.chain, 50); // a quarter of a 200 € kit
      // 6000 * (1 - e^(-(0.04 + 0.005 * 5) * 3)) / 3
      expect(c.depreciation, closeTo(354.33, 0.01));
      expect(c.perYear, closeTo(797.95, 0.01));
      expect(c.total, closeTo(2393.85, 0.01));
      expect(
        ownershipHeadline(c),
        'Custa cerca de ${Formatters.price(800)} por ano',
      );
      expect(
        ownershipTotalLine(c),
        'Em 3 anos: cerca de ${Formatters.price(2390)}',
      );
    });

    test('uses the owner insurance, km and years and the model rates', () {
      final c = ownershipCost(
        price: 10000,
        settings: const OwnershipSettings(
          insurancePerYear: 300,
          kmPerYear: 20000,
          yearsToKeep: 1,
        ),
        engineCc: 998,
        year: 2022,
        depreciation: const Depreciation(
          sampleCount: 40,
          isFitted: true,
          perYear: 0.08,
          per1000Km: 0.01,
        ),
      )!;
      expect(c.insurance, 300);
      expect(c.iuc, 138.15);
      expect(c.tyres, 950); // 2.5 sets of 380 €
      expect(c.services, 500); // two services of 250 €
      expect(c.chain, 260);
      // 10000 * (1 - e^(-(0.08 + 0.01 * 20)))
      expect(c.depreciation, closeTo(2442.16, 0.01));
      expect(c.total, c.perYear);
    });

    test(
      'tyres age out and a service is due every year when little ridden',
      () {
        final c = ownershipCost(
          price: 5000,
          settings: const OwnershipSettings(kmPerYear: 0),
          engineCc: 125,
        )!;
        expect(c.tyres, 40); // a 200 € set every 5 years
        expect(c.services, 130);
        expect(c.chain, 0);
      },
    );

    test('none without a price', () {
      const s = OwnershipSettings();
      expect(ownershipCost(price: null, settings: s), isNull);
      expect(ownershipCost(price: 0, settings: s), isNull);
    });
  });

  group('ownershipLines', () {
    OwnershipCost cost({int? cc = 695, int? year = 2021, int? insurance}) =>
        ownershipCost(
          price: 6000,
          settings: OwnershipSettings(insurancePerYear: insurance),
          engineCc: cc,
          year: year,
        )!;

    test('every part with its basis', () {
      final lines = ownershipLines(cost(insurance: 250), year: 2021);
      expect(lines, [
        'Desvalorização: ${Formatters.price(350)} por ano (média de 3 anos)',
        'IUC: ${Formatters.price(63.62)}',
        'Seguro: ${Formatters.price(250)} (o seu valor)',
        'Pneus: ${Formatters.price(150)} (um jogo a cada '
            '${Formatters.mileage(10000)}, pelo menos a cada 5 anos)',
        'Revisões: ${Formatters.price(180)} (a cada '
            '${Formatters.mileage(10000)}, pelo menos uma por ano)',
        'Kit de transmissão: ${Formatters.price(50)} (a cada '
            '${Formatters.mileage(20000)})',
      ]);
    });

    test('says what is missing or not charged', () {
      expect(ownershipLines(cost())[2], startsWith('Seguro: não incluído'));
      expect(
        ownershipLines(cost(cc: null))[1],
        'IUC: cilindrada do modelo desconhecida',
      );
      expect(
        ownershipLines(cost(year: 1995), year: 1995)[1],
        'IUC: não calculado para matrículas anteriores a 1997',
      );
      expect(
        ownershipLines(cost(cc: 125))[1],
        'IUC: não paga (menos de 10 € por ano)',
      );
    });

    test('one year reads in the singular', () {
      final c = ownershipCost(
        price: 6000,
        settings: const OwnershipSettings(yearsToKeep: 1),
      )!;
      expect(ownershipTotalLine(c), startsWith('Em 1 ano: '));
      expect(ownershipLines(c).first, endsWith('(média de 1 ano)'));
    });
  });

  group('parseOwnershipSettings', () {
    test('reads whole numbers, with spaces, dots or €', () {
      expect(
        parseOwnershipSettings(
          insurance: ' 1.250 € ',
          kmPerYear: '8 000',
          yearsToKeep: '4',
        ),
        const OwnershipSettings(
          insurancePerYear: 1250,
          kmPerYear: 8000,
          yearsToKeep: 4,
        ),
      );
    });

    test('an empty insurance means not given', () {
      expect(
        parseOwnershipSettings(
          insurance: '',
          kmPerYear: '0',
          yearsToKeep: '15',
        ),
        const OwnershipSettings(kmPerYear: 0, yearsToKeep: 15),
      );
    });

    test('refuses what the database would refuse', () {
      OwnershipSettings? parse(String i, String k, String y) =>
          parseOwnershipSettings(insurance: i, kmPerYear: k, yearsToKeep: y);
      expect(parse('abc', '5000', '3'), isNull);
      expect(parse('20001', '5000', '3'), isNull);
      expect(parse('-5', '5000', '3'), isNull);
      expect(parse('', '', '3'), isNull);
      expect(parse('', '100001', '3'), isNull);
      expect(parse('', '5000', '0'), isNull);
      expect(parse('', '5000', '16'), isNull);
      expect(parse('', '5000', '2,5'), isNull);
      expect(parse('20000', '100000', '1'), isNotNull);
    });
  });

  test('engine size is the middle of the model range', () {
    expect(
      ListingModel.engineCcOf({'engine_cc_min': 680, 'engine_cc_max': 710}),
      695,
    );
    expect(
      ListingModel.engineCcOf({'engine_cc_min': 750, 'engine_cc_max': 760}),
      755,
    );
    expect(ListingModel.engineCcOf({'engine_cc_min': 650}), 650);
    expect(ListingModel.engineCcOf({'engine_cc_max': 700}), 700);
    expect(ListingModel.engineCcOf({}), isNull);
    expect(ListingModel.engineCcOf(null), isNull);
  });
}
