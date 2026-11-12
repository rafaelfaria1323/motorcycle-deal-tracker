import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/valuation/data/repositories/supabase_owned_bikes_repository.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/owned_bike.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/owned_bike_text.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/ownership_cost.dart';

OwnedBikeDraft _bike({int? km = 12000, int? paid = 5600, DateTime? on}) =>
    OwnedBikeDraft(
      motorcycleId: 'mt07',
      year: 2021,
      boughtOn: on ?? DateTime(2026, 1, 1),
      pricePaid: paid,
      mileageAtPurchase: km,
    );

String _price(double v) => Formatters.price(v);
String _km(int v) => Formatters.mileage(v);

void main() {
  group('mileageNow', () {
    test('adds the km a year for the time since, to the nearest 100', () {
      // Half a year (182 days) at 5 000 km a year: about 2 500.
      expect(
        mileageNow(_bike(), kmPerYear: 5000, today: DateTime(2026, 7, 2)),
        14500,
      );
    });

    test('the km at purchase on the day, or a date still to come', () {
      expect(
        mileageNow(_bike(), kmPerYear: 5000, today: DateTime(2026, 1, 1)),
        12000,
      );
      expect(
        mileageNow(_bike(), kmPerYear: 5000, today: DateTime(2025, 12, 1)),
        12000,
      );
    });

    test('unknown without the km at purchase', () {
      expect(
        mileageNow(
          _bike(km: null),
          kmPerYear: 5000,
          today: DateTime(2027, 1, 1),
        ),
        isNull,
      );
    });
  });

  group('purchaseText', () {
    test('says what is known', () {
      expect(
        purchaseText(_bike(km: null, paid: null)),
        'Comprada em 01/01/2026',
      );
      expect(
        purchaseText(_bike(km: null)),
        'Comprada em 01/01/2026 por ${_price(5600)}',
      );
      expect(
        purchaseText(_bike()),
        'Comprada em 01/01/2026 por ${_price(5600)}, com ${_km(12000)}',
      );
      expect(
        purchaseText(_bike(paid: null), language: .english),
        'Bought on 01/01/2026, with ${Formatters.mileage(12000, language: .english)}',
      );
    });
  });

  group('value against what was paid', () {
    const worth = BikeValue(comparableCount: 8, estimate: 5400);

    test('no change without an estimate or a price', () {
      expect(valueChange(const BikeValue(comparableCount: 1), 5600), isNull);
      expect(valueChange(worth, null), isNull);
      expect(valueChange(worth, 0), isNull);
    });

    test('below, above and about the same', () {
      final below = valueChange(worth, 6000)!;
      expect(below.change, -600);
      expect(below.share, closeTo(-0.1, 1e-9));
      expect(
        valueChangeText(below),
        '${_price(600)} (${Formatters.percent(10, decimals: 1)}) abaixo do que pagou',
      );
      final above = valueChange(worth, 5000)!;
      expect(valueChangeText(above), contains('acima do que pagou'));
      expect(
        valueChangeText(valueChange(worth, 5420)!),
        'Mais ou menos o que pagou',
      );
    });

    test('value today, or why it is not known', () {
      expect(valueTodayText(worth), 'Vale hoje cerca de ${_price(5400)}');
      expect(
        valueTodayText(const BikeValue(comparableCount: 1)),
        startsWith('Ainda sem anúncios'),
      );
    });
  });

  group('nextMaintenance', () {
    test('the next multiple of each interval, soonest first', () {
      final due = nextMaintenance(14500, smallBikeCosts);
      expect(due.map((d) => d.kind), [
        MaintenanceKind.service,
        MaintenanceKind.valveCheck,
      ]);
      expect(due.first.atKm, 18000);
      expect(due.first.inKm, 3500);
      expect(due.last.atKm, 24000);
      expect(due.last.cost, smallBikeCosts.valveCheck);
    });

    test('right on an interval is due now', () {
      final due = nextMaintenance(24000, smallBikeCosts);
      expect(due.every((d) => d.inKm == 0), isTrue);
      expect(
        maintenanceText(due.first),
        'Revisão já aos ${_km(24000)}: cerca de ${roughPrice(smallBikeCosts.service)}',
      );
    });

    test('names the km left', () {
      final due = nextMaintenance(14500, smallBikeCosts).first;
      expect(
        maintenanceText(due),
        'Revisão aos ${_km(18000)} (faltam ${_km(3500)}): '
        'cerca de ${roughPrice(smallBikeCosts.service)}',
      );
    });
  });

  group('parseOwnedBike', () {
    final on = DateTime(2026, 11, 12, 15, 30);
    OwnedBikeDraft? parse({
      String year = '2021',
      String price = '',
      String mileage = '',
    }) => parseOwnedBike(
      motorcycleId: 'mt07',
      year: year,
      price: price,
      mileage: mileage,
      boughtOn: on,
      listingId: 'ad',
    );

    test('reads separators and keeps the day only', () {
      final bike = parse(price: '5 600', mileage: '12.000')!;
      expect(bike.pricePaid, 5600);
      expect(bike.mileageAtPurchase, 12000);
      expect(bike.boughtOn, DateTime(2026, 11, 12));
      expect(bike.listingId, 'ad');
    });

    test('price and km may stay blank, the year may not', () {
      expect(parse()!.pricePaid, isNull);
      expect(parse(year: ''), isNull);
    });

    test('refuses what the database would', () {
      expect(parse(year: '1949'), isNull);
      expect(parse(year: '2028'), isNull);
      expect(parse(year: '2027'), isNotNull);
      expect(parse(price: '200001'), isNull);
      expect(parse(price: '5600€'), isNull);
      expect(parse(mileage: '500001'), isNull);
      expect(parse(mileage: '-5'), isNull);
    });
  });

  group('owned_bikes rows', () {
    test('a row with its model', () {
      final bike = ownedBikeFrom({
        'id': 'b1',
        'motorcycle_id': 'mt07',
        'listing_id': null,
        'year': 2021,
        'price_paid': 5600,
        'mileage_at_purchase': null,
        'bought_on': '2026-03-04',
        'motorcycles': {
          'brand': 'Yamaha',
          'model': 'MT-07',
          'engine_cc_min': 680,
          'engine_cc_max': 700,
          'service_interval_km': 10000,
        },
      });
      expect(bike.name, 'Yamaha MT-07');
      expect(bike.engineCc, 690);
      expect(bike.maintenance?.serviceIntervalKm, 10000);
      expect(bike.purchase, _bike(km: null, on: DateTime(2026, 3, 4)));
    });

    test('a draft as a row', () {
      expect(ownedBikeRow(_bike(on: DateTime(2026, 3, 4))), {
        'motorcycle_id': 'mt07',
        'listing_id': null,
        'year': 2021,
        'price_paid': 5600,
        'mileage_at_purchase': 12000,
        'bought_on': '2026-03-04',
      });
    });
  });
}
