import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_market_behaviour_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseMarketBehaviourRepository repository;
  late List<Request> requests;
  late int status;
  late DateTime now;

  setUp(() {
    requests = [];
    status = 200;
    now = DateTime(2026, 10, 27, 12);
    client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = status != 200
            ? '{"code":"42501","message":"Permission denied"}'
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
}
