import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_maintenance.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/valuation/data/repositories/supabase_fuel_price_repository.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/fuel_price.dart';
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

  test('a sports bike\'s tyres cost more and last less', () {
    final sport = runningCostsFor(695, sport: true);
    expect(sport.tyreSet, closeTo(345, 0.001));
    expect(sport.tyreLifeKm, 8000);
    expect(sport.service, middleBikeCosts.service);
    expect(sport.serviceIntervalKm, middleBikeCosts.serviceIntervalKm);
    expect(sport.chainKit, middleBikeCosts.chainKit);
    expect(sport.chainLifeKm, middleBikeCosts.chainLifeKm);
    expect(runningCostsFor(998, sport: true).tyreLifeKm, 6400);
  });

  group('the model\'s own figures (N.60)', () {
    const mt07 = BikeMaintenance(
      frontTyre: '120/70-17',
      rearTyre: '180/55-17',
      cylinders: 2,
      serviceIntervalKm: 10000,
      valveCheckKm: 40000,
    );
    const cb650r = BikeMaintenance(
      frontTyre: '120/70-17',
      rearTyre: '180/55-17',
      cylinders: 4,
      serviceIntervalKm: 12000,
      valveCheckKm: 38400,
    );

    test('one tyre by its width', () {
      expect(tyrePrice('110/70-17'), 85);
      expect(tyrePrice('120/70-17'), 120);
      expect(tyrePrice('140/70-17'), 120);
      expect(tyrePrice('150/60-17'), 135);
      expect(tyrePrice('160/60-17'), 155);
      expect(tyrePrice('180/55-17'), 185);
      expect(tyrePrice('190/55-17'), 210);
      expect(tyrePrice('200/55-17'), 230);
      expect(tyrePrice('120/70 ZR17'), isNull);
      expect(tyrePrice(null), isNull);
    });

    test('tyres by size, services and valves by cylinders and intervals', () {
      final t = runningCostsFor(695, maintenance: mt07);
      expect(t.tyreSet, 335); // 120 + 185 + 30 fitting
      expect((t.frontTyre, t.rearTyre), ('120/70-17', '180/55-17'));
      expect(t.tyreLifeKm, middleBikeCosts.tyreLifeKm);
      expect(t.service, 180);
      expect(t.serviceIntervalKm, 10000);
      expect(t.valveCheck, 350);
      expect(t.valveCheckKm, 40000);
      expect(t.chainKit, middleBikeCosts.chainKit);

      final four = runningCostsFor(649, sport: true, maintenance: cb650r);
      expect(four.tyreSet, closeTo(335 * 1.15, 0.001));
      expect(four.tyreLifeKm, 8000);
      expect(four.service, 220);
      expect(four.serviceIntervalKm, 12000);
      expect(four.valveCheck, 550);
      expect(four.valveCheckKm, 38400);

      expect(
        runningCostsFor(
          125,
          maintenance: const BikeMaintenance(cylinders: 1),
        ).valveCheck,
        180,
      );
      expect(
        runningCostsFor(
          1100,
          maintenance: const BikeMaintenance(cylinders: 6),
        ).service,
        220,
      );
    });

    test('what the model lacks comes from the engine-size table', () {
      final t = runningCostsFor(
        695,
        maintenance: const BikeMaintenance(frontTyre: '120/70-17'),
      );
      expect(t.tyreSet, middleBikeCosts.tyreSet); // both sizes needed
      expect(t.frontTyre, isNull);
      expect(t.service, middleBikeCosts.service);
      expect(t.serviceIntervalKm, middleBikeCosts.serviceIntervalKm);
      expect(t.valveCheck, middleBikeCosts.valveCheck);
      expect(t.valveCheckKm, middleBikeCosts.valveCheckKm);
    });

    test('lines name the tyre sizes and the valve check', () {
      final c = ownershipCost(
        price: 6000,
        settings: const OwnershipSettings(insurancePerYear: 250),
        engineCc: 695,
        year: 2021,
        maintenance: mt07,
      )!;
      expect(c.tyres, 167.5); // half a 335 € set
      expect(c.valves, 43.75); // 350 € every 40 000 km at 5 000 a year
      final lines = ownershipLines(c, year: 2021);
      expect(
        lines[3],
        'Pneus: ${Formatters.price(167.5)} (120/70-17 e 180/55-17, um jogo '
        'a cada ${Formatters.mileage(10000)}, pelo menos a cada 5 anos)',
      );
      expect(
        lines.last,
        'Folga das válvulas: ${Formatters.price(43.75)} '
        '(${Formatters.price(350)} a cada ${Formatters.mileage(40000)})',
      );
      const en = AppLanguage.english;
      final english = ownershipLines(c, year: 2021, language: en);
      expect(
        english[3],
        'Tyres: ${Formatters.price(167.5, language: en)} (120/70-17 and '
        '180/55-17, a set every ${Formatters.mileage(10000, language: en)}, '
        'at least every 5 years)',
      );
      expect(
        english.last,
        'Valve clearance check: ${Formatters.price(43.75, language: en)} '
        '(${Formatters.price(350, language: en)} every '
        '${Formatters.mileage(40000, language: en)})',
      );
    });

    test('read from the catalog row', () {
      expect(
        ListingModel.maintenanceOf({
          'front_tyre': '120/70-17',
          'rear_tyre': '180/55-17',
          'cylinders': 2,
          'service_interval_km': 10000,
          'valve_check_km': 40000,
        }),
        mt07,
      );
      expect(
        ListingModel.maintenanceOf({'engine_cc_min': 680, 'cylinders': null}),
        isNull,
      );
      expect(ListingModel.maintenanceOf(null), isNull);
    });
  });

  group('isSportBike', () {
    test('fully faired sports bikes by brand', () {
      for (final (brand, model) in [
        ('Yamaha', 'R7'),
        ('Yamaha', 'R1'),
        ('Yamaha', 'YZF-R125'),
        ('Honda', 'CBR650R'),
        ('Honda', 'CBR 600 RR'),
        ('Kawasaki', 'Ninja 650'),
        ('Kawasaki', 'ZX-6R'),
        ('Suzuki', 'GSX-R750'),
        ('Ducati', 'Panigale V2'),
        ('Aprilia', 'RS 660'),
        ('KTM', 'RC 390'),
        ('BMW', 'S 1000 RR'),
        ('Triumph', 'Daytona 660'),
        ('MV Agusta', 'F3 800'),
      ]) {
        expect(
          isSportBike(brand: brand, model: model),
          isTrue,
          reason: model,
        );
      }
    });

    test('nakeds, tourers and unknown brands are not', () {
      for (final (brand, model) in [
        ('Yamaha', 'MT-07'),
        ('Yamaha', 'Tracer 7'),
        ('Honda', 'CB650R'),
        ('Honda', 'CB750 Hornet'),
        ('BMW', 'R 1250 GS'),
        ('Kawasaki', 'Z900'),
        ('Suzuki', 'GSX-S750'),
        ('Aprilia', 'Tuono 660'),
        ('Benelli', 'R1'),
      ]) {
        expect(
          isSportBike(brand: brand, model: model),
          isFalse,
          reason: model,
        );
      }
    });
  });

  group('insuranceEstimate', () {
    test('by engine size band', () {
      expect(insuranceEstimate(125), 90);
      expect(insuranceEstimate(126), 150);
      expect(insuranceEstimate(400), 150);
      expect(insuranceEstimate(695), 230);
      expect(insuranceEstimate(800), 230);
      expect(insuranceEstimate(998), 340);
      expect(insuranceEstimate(null), 230);
    });

    test('a third more for a sports bike', () {
      expect(insuranceEstimate(125, sport: true), 117);
      expect(insuranceEstimate(689, sport: true), 299);
      expect(insuranceEstimate(998, sport: true), 442);
    });

    test('band limits', () {
      expect(insuranceBandFor(125), (minCc: null, maxCc: 125, euros: 90.0));
      expect(insuranceBandFor(300), (minCc: 126, maxCc: 400, euros: 150.0));
      expect(insuranceBandFor(1000), (minCc: 801, maxCc: null, euros: 340.0));
    });
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
      expect(c.insurance, 230); // the estimate for 401 to 800 cc
      expect(c.insuranceEstimated, isTrue);
      expect(c.tyres, 150); // half a 300 € set at 5 000 of 10 000 km
      expect(c.services, 180); // one a year
      expect(c.chain, 50); // a quarter of a 200 € kit
      expect(c.valves, closeTo(58.33, 0.01)); // 350 € every 30 000 km
      // 6000 * (1 - e^(-(0.04 + 0.005 * 5) * 3)) / 3
      expect(c.depreciation, closeTo(354.33, 0.01));
      expect(c.perYear, closeTo(1086.28, 0.01));
      expect(c.total, closeTo(3258.85, 0.01));
      expect(
        ownershipHeadline(c),
        'Custa cerca de ${Formatters.price(1090)} por ano',
      );
      expect(
        ownershipTotalLine(c),
        'Em 3 anos: cerca de ${Formatters.price(3260)}',
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
      expect(c.insuranceEstimated, isFalse);
      expect(c.iuc, 138.15);
      expect(c.tyres, 950); // 2.5 sets of 380 €
      expect(c.services, 500); // two services of 250 €
      expect(c.chain, 260);
      expect(c.valves, closeTo(366.67, 0.01)); // 550 € every 30 000 km
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
        expect(c.valves, 0);
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
        'Folga das válvulas: ${Formatters.price(350 * 5000 / 30000)} '
            '(${Formatters.price(350)} a cada ${Formatters.mileage(30000)})',
      ]);
    });

    test('estimates the insurance until the owner enters it', () {
      final price = Formatters.price(230);
      expect(
        ownershipLines(cost())[2],
        'Seguro: cerca de $price (estimativa contra terceiros, 401 a 800 cc; '
        'indique o seu valor)',
      );
      expect(
        ownershipLines(cost(cc: 125))[2],
        'Seguro: cerca de ${Formatters.price(90)} (estimativa contra '
        'terceiros, até 125 cc; indique o seu valor)',
      );
      expect(ownershipLines(cost(cc: 998))[2], contains('mais de 800 cc'));
      expect(
        ownershipLines(cost(cc: null))[2],
        contains('cilindrada desconhecida'),
      );
      final sport = ownershipCost(
        price: 8000,
        settings: const OwnershipSettings(),
        engineCc: 689,
        sport: true,
      )!;
      expect(sport.tyres, closeTo(215.63, 0.01)); // 345 € every 8 000 km
      expect(
        ownershipLines(sport)[2],
        'Seguro: cerca de ${Formatters.price(299)} (estimativa contra '
        'terceiros, desportiva de 401 a 800 cc; indique o seu valor)',
      );
      expect(
        ownershipLines(sport, language: AppLanguage.english)[2],
        'Insurance: about ${Formatters.price(299, language: AppLanguage.english)} '
        '(third-party estimate, 401 to 800 cc sports bike; enter your own '
        'figure)',
      );
    });

    test('says what is missing or not charged', () {
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

  group('fuel (N.74)', () {
    final pump = FuelPrice(perLitre: 1.9, day: DateTime(2026, 11, 11));
    const settings = OwnershipSettings(insurancePerYear: 250);

    test('the maker\'s figure at the national price', () {
      final c = ownershipCost(
        price: 6000,
        settings: settings,
        engineCc: 695,
        maintenance: const BikeMaintenance(fuelPer100Km: 4.2),
        fuelPrice: pump,
      )!;
      // 5 000 km at 4.2 l/100 km = 210 l at 1.9 €.
      expect(c.fuel, closeTo(399, 1e-9));
      expect(c.fuelPer100Km, 4.2);
      expect(c.fuelEstimated, isFalse);
      final without = ownershipCost(
        price: 6000,
        settings: settings,
        engineCc: 695,
        maintenance: const BikeMaintenance(fuelPer100Km: 4.2),
      )!;
      expect(c.perYear - without.perYear, closeTo(399, 1e-9));
      expect(
        ownershipLines(c).last,
        'Combustível: ${Formatters.price(399)} (4,2 l/100 km do fabricante, '
        'gasolina 95 a 1,900 €/l, média nacional de 11/11/2026)',
      );
      expect(
        ownershipLines(c, language: AppLanguage.english).last,
        'Fuel: ${Formatters.price(399, language: AppLanguage.english)} '
        "(4.2 l/100 km, the maker's figure; petrol 95 at 1.900 €/l, "
        'national average on 11/11/2026)',
      );
    });

    test('estimated by engine size without the maker\'s figure', () {
      final c = ownershipCost(
        price: 3000,
        settings: const OwnershipSettings(kmPerYear: 10000),
        engineCc: 125,
        fuelPrice: pump,
      )!;
      expect(c.fuelPer100Km, 2.2);
      expect(c.fuelEstimated, isTrue);
      expect(c.fuel, closeTo(418, 1e-9));
      expect(ownershipLines(c).last, startsWith('Combustível: '));
      expect(ownershipLines(c).last, contains('cerca de 2,2 l/100 km'));
    });

    test('no fuel line without a price', () {
      final c = ownershipCost(
        price: 6000,
        settings: settings,
        engineCc: 695,
        maintenance: const BikeMaintenance(fuelPer100Km: 4.2),
      )!;
      expect(c.fuel, isNull);
      expect(c.fuelPer100Km, isNull);
      expect(ownershipLines(c).last, startsWith('Folga das válvulas'));
    });

    test('consumption bands by engine size', () {
      expect(fuelConsumptionEstimate(125), 2.2);
      expect(fuelConsumptionEstimate(150), 2.2);
      expect(fuelConsumptionEstimate(151), 3.2);
      expect(fuelConsumptionEstimate(321), 3.2);
      expect(fuelConsumptionEstimate(471), 3.8);
      expect(fuelConsumptionEstimate(695), 4.6);
      expect(fuelConsumptionEstimate(800), 4.6);
      expect(fuelConsumptionEstimate(998), 6.0);
      expect(fuelConsumptionEstimate(null), 4.6);
    });

    test('read from the catalog row and fuel_prices', () {
      expect(
        ListingModel.maintenanceOf({'fuel_l_per_100km': 4.2}),
        const BikeMaintenance(fuelPer100Km: 4.2),
      );
      expect(
        fuelPriceOf({'price': 1.911, 'day': '2026-11-11'}),
        FuelPrice(perLitre: 1.911, day: DateTime(2026, 11, 11)),
      );
      expect(fuelPriceOf({'price': null, 'day': '2026-11-11'}), isNull);
      expect(fuelPriceOf({'price': 1.9, 'day': 'x'}), isNull);
    });
  });
}
