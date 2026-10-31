import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseListingsRepository repository;
  late List<Request> requests;

  setUp(() {
    requests = [];
    client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseListingsRepository(client);
  });

  tearDown(() => client.dispose());

  Future<Map<String, String>> query({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
  }) async {
    await repository.getListings(filters: filters, sort: sort);
    return requests.single.url.queryParameters;
  }

  // "1 €" ads (asking_price null) go after every real price, either way.
  test(
    'the price sorts order by the asking price, placeholders last',
    () async {
      expect(
        (await query(sort: ListingSort.priceAsc))['order'],
        startsWith('asking_price.asc.nullslast,'),
      );
      requests.clear();
      expect(
        (await query(sort: ListingSort.priceDesc))['order'],
        startsWith('asking_price.desc.nullslast,'),
      );
    },
  );

  test('a maximum price never matches a placeholder', () async {
    final parameters = await query(
      filters: const ListingFilters(maxPrice: 8000),
    );
    expect(parameters['asking_price'], startsWith('lte.8000'));
    expect(parameters.containsKey('price'), isFalse);
  });

  test('the newest first is the order web/index.html prefetches', () async {
    expect((await query())['order'], startsWith('first_seen_at.desc'));
  });
}
