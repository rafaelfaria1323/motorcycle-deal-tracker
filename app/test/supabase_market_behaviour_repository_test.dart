import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/market/data/repositories/supabase_market_behaviour_repository.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value_request.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/exit_price.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/market_behaviour.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseMarketBehaviourRepository repository;
  late List<Request> requests;
  late int status;
  late DateTime now;

  /// The response when set, instead of the one picked by the address.
  String? reply;

  setUp(() {
    requests = [];
    status = 200;
    reply = null;
    now = DateTime(2026, 10, 27, 12);
    client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = reply != null
            ? reply!
            : status != 200
            ? '{"code":"42501","message":"Permission denied"}'
            : request.url.path.endsWith('bike_value')
            ? '[{"comparable_count":3,"fair_price":6000,'
                  '"low_price":5800,"high_price":6200}]'
            : request.url.path.endsWith('model_market_behaviour')
            ? '{"live_count":12,"gone_count":30,"priced_count":40,'
                  '"dropped_count":9,"median_days_to_gone":21}'
            : '{"sample_count":42,"is_fitted":true,"per_year":0.06,'
                  '"per_1000km":0.004}';
        return Response(
          body,
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseMarketBehaviourRepository(client, clock: () => now);
  });

  tearDown(() => client.dispose());

  test('the cards of one listing page share one read of the model', () async {
    final figures = await Future.wait([
      for (var i = 0; i < 4; i++) repository.getForModel('m1'),
    ]);
    expect(requests, hasLength(2));
    expect(figures.toSet(), hasLength(1));
    expect(figures.first!.liveCount, 12);
    expect(figures.first!.depreciation!.sampleCount, 42);

    await repository.getForModel('m2');
    expect(requests, hasLength(4));
  });

  test('the figures are read again once they are old', () async {
    await repository.getForModel('m1');
    now = now.add(
      SupabaseMarketBehaviourRepository.reuseFor - const Duration(seconds: 1),
    );
    await repository.getForModel('m1');
    expect(requests, hasLength(2));

    now = now.add(const Duration(seconds: 1));
    await repository.getForModel('m1');
    expect(requests, hasLength(4));
  });

  test('a failed read is not kept', () async {
    status = 403;
    await expectLater(repository.getForModel('m1'), throwsA(anything));
    expect(requests, hasLength(2));

    status = 200;
    expect((await repository.getForModel('m1'))!.liveCount, 12);
    expect(requests, hasLength(4));
  });

  test('priceTrendWeekFrom reads a row of model_price_trend', () {
    final week = priceTrendWeekFrom({
      'motorcycle_id': 'm1',
      'week_start': '2026-10-19',
      'listing_count': 12,
      'median_price': 7250,
      'median_adjusted_price': 7100.5,
    });
    expect(week.weekStart, DateTime(2026, 10, 19));
    expect(week.count, 12);
    expect(week.median, 7250);
    expect(week.adjustedMedian, 7100.5);
  });

  test('timeToSaleFrom reads the row of listing_time_to_sale', () {
    expect(
      timeToSaleFrom({
        'band': 'below',
        'gone_count': 7,
        'live_count': 12,
        'days_listed': 9,
        'typical_days': 20,
        'remaining_days': 11,
      }),
      const TimeToSale(
        band: PriceBand.below,
        goneCount: 7,
        liveCount: 12,
        daysListed: 9,
        typicalDays: 20,
        remainingDays: 11,
      ),
    );
    expect(
      timeToSaleFrom({
        'band': null,
        'gone_count': 2,
        'live_count': 3,
        'days_listed': 0,
        'typical_days': null,
        'remaining_days': null,
      }),
      const TimeToSale(goneCount: 2, liveCount: 3, daysListed: 0),
    );
    expect(
      timeToSaleFrom({
        'band': 'near',
        'gone_count': 5,
        'live_count': 0,
        'days_listed': 1,
      }).band,
      PriceBand.near,
    );
    expect(
      timeToSaleFrom({
        'band': 'above',
        'gone_count': 5,
        'live_count': 0,
        'days_listed': 1,
      }).band,
      PriceBand.above,
    );
  });

  test('getTimeToSale asks for the listing; no row reads as null', () async {
    reply =
        '[{"band":null,"gone_count":6,"live_count":4,"days_listed":3,'
        '"typical_days":15,"remaining_days":12}]';
    final t = await repository.getTimeToSale('l1');
    expect(requests.single.url.path, endsWith('listing_time_to_sale'));
    expect(jsonDecode(requests.single.body), {'p_listing_id': 'l1'});
    expect(t!.remainingDays, 12);

    reply = '[]';
    expect(await repository.getTimeToSale('l2'), isNull);
  });

  test('bikeValueFrom reads the row of bike_value', () {
    final value = bikeValueFrom({
      'comparable_count': 7,
      'fair_price': 6300.5,
      'low_price': 6100,
      'high_price': 6450,
    });
    expect(value.comparableCount, 7);
    expect(value.estimate, 6300.5);
    expect(value.low, 6100);
    expect(value.high, 6450);

    final none = bikeValueFrom({
      'comparable_count': 0,
      'fair_price': null,
      'low_price': null,
      'high_price': null,
    });
    expect(none.estimate, isNull);
  });

  test(
    'getBikeValue asks bike_value for the model, year and mileage',
    () async {
      final value = await repository.getBikeValue('m1', year: 2020);
      expect(requests.single.url.path, endsWith('/rpc/bike_value'));
      expect(jsonDecode(requests.single.body), {
        'p_motorcycle_id': 'm1',
        'p_year': 2020,
        'p_mileage': null,
      });
      expect(value.comparableCount, 3);
      expect(value.estimate, 6000);
    },
  );

  test('getExitPrice asks exit_price for the model, year, km and ad', () async {
    reply = '[{"gone_count":7,"median_price":6100.5}]';
    final exit = await repository.getExitPrice(
      'm1',
      year: 2020,
      mileage: 15000,
      except: 'l1',
    );
    expect(requests.single.url.path, endsWith('/rpc/exit_price'));
    expect(jsonDecode(requests.single.body), {
      'p_motorcycle_id': 'm1',
      'p_year': 2020,
      'p_mileage': 15000,
      'p_except': 'l1',
    });
    expect(exit, const ExitPrice(goneCount: 7, median: 6100.5));

    expect(
      exitPriceFrom({'gone_count': 0, 'median_price': null}),
      const ExitPrice(goneCount: 0),
    );
  });

  test('requestBikeValue asks for the bike and says if it is ready', () async {
    reply = '[{"request_id":"r1","ready":false}]';
    final asked = await repository.requestBikeValue(
      'm1',
      year: 2019,
      mileage: 30000,
    );
    expect(requests.single.url.path, endsWith('/rpc/request_bike_value'));
    expect(jsonDecode(requests.single.body), {
      'p_motorcycle_id': 'm1',
      'p_year': 2019,
      'p_mileage': 30000,
    });
    expect(asked, (requestId: 'r1', ready: false));
  });

  test('the cap on waiting requests reads as BikeValueRequestLimit', () async {
    status = 400;
    reply = '{"code":"54000","message":"3 requests waiting today"}';
    await expectLater(
      repository.requestBikeValue('m1', year: 2019),
      throwsA(isA<BikeValueRequestLimit>()),
    );

    reply = null;
    await expectLater(
      repository.requestBikeValue('m1', year: 2019),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('bikeValueModel sends the make, model and searches', () async {
    reply = '"m9"';
    final id = await repository.bikeValueModel(
      brand: 'Kawasaki',
      model: 'Z650',
      standvirtualSearch: 'https://www.standvirtual.com/motos/kawasaki/z650',
    );
    expect(id, 'm9');
    expect(requests.single.url.path, endsWith('/rpc/bike_value_model'));
    expect(jsonDecode(requests.single.body), {
      'p_brand': 'Kawasaki',
      'p_model': 'Z650',
      'p_olx_search': null,
      'p_standvirtual_search':
          'https://www.standvirtual.com/motos/kawasaki/z650',
      'p_engine_cc_min': null,
      'p_engine_cc_max': null,
    });
  });

  test('bikeValueRequestFrom reads a request with its model', () {
    final request = bikeValueRequestFrom({
      'id': 'r1',
      'motorcycle_id': 'm1',
      'year': 2019,
      'mileage': null,
      'requested_at': '2026-10-28T09:00:00Z',
      'answered_at': null,
      'motorcycles': {'brand': 'Kawasaki', 'model': 'Z650'},
    });
    expect(request.name, 'Kawasaki Z650');
    expect(request.waiting, isTrue);
    expect(request.mileage, isNull);
    expect(request.requestedAt, DateTime.utc(2026, 10, 28, 9));

    final answered = bikeValueRequestFrom({
      'id': 'r2',
      'motorcycle_id': 'm1',
      'year': 2019,
      'mileage': 30000,
      'requested_at': '2026-10-28T09:00:00Z',
      'answered_at': '2026-10-28T10:30:00Z',
      'motorcycles': {'brand': 'Kawasaki', 'model': 'Z650'},
    });
    expect(answered.waiting, isFalse);
    expect(answered.mileage, 30000);
  });

  test('getBikeValueRequests reads the newest 20 with their models', () async {
    reply = '[]';
    expect(await repository.getBikeValueRequests(), isEmpty);
    final url = requests.single.url;
    expect(url.path, endsWith('/bike_value_requests'));
    expect(url.queryParameters['order'], 'requested_at.desc.nullslast');
    expect(url.queryParameters['limit'], '20');
    expect(url.queryParameters['select'], contains('motorcycles(brand,model)'));
  });
}
