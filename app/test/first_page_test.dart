import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:motorcycle_deal_tracker/features/listings/data/models/first_page_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers every request with no rows and keeps its address.
class _Recorder extends http.BaseClient {
  final urls = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// The query `web/index.html` asks for [table] with.
Map<String, String> _pageQuery(String table) {
  final html = File('web/index.html').readAsStringSync();
  final constant = RegExp(
    "var \\w+ = '($table\\?(?:[^;])*?)';",
    dotAll: true,
  ).firstMatch(html);
  expect(constant, isNotNull, reason: 'no $table query in index.html');
  // The script joins its string with "' +" and a new line.
  final query = constant!.group(1)!.replaceAll(RegExp(r"' \+\s+'"), '');
  return Uri.parse('https://db.example/rest/v1/$query').queryParameters;
}

void main() {
  test("index.html asks for the app's own first page", () async {
    final recorder = _Recorder();
    final client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      httpClient: recorder,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final repository = SupabaseListingsRepository(client);

    await repository.getListings(
      sort: const ListingsState().sort,
      limit: ListingsCubit.pageSize,
    );
    await repository.getMotorcycleOptions();
    await client.dispose();

    expect(const ListingsState().sort, ListingSort.dealScoreDesc);
    expect(recorder.urls, hasLength(2));
    expect(_pageQuery('listings'), recorder.urls[0].queryParameters);
    expect(_pageQuery('motorcycles'), recorder.urls[1].queryParameters);
  });

  test('reads the answer index.html got', () {
    final page = firstPageFromJson(
      jsonEncode({
        'listings': [
          {
            'id': 'l1',
            'source': 'olx',
            'url': 'https://www.olx.pt/d/anuncio/1.html',
            'brand': 'Yamaha',
            'model': 'MT-07',
            'images': ['https://ireland.apollo.olxcdn.com/v1/files/a/image'],
            'status': 'active',
          },
        ],
        'motorcycles': [
          {'id': 'm1', 'brand': 'Yamaha', 'model': 'MT-07'},
        ],
      }),
    );

    expect(page!.listings.single.id, 'l1');
    expect(page.listings.single.images, hasLength(1));
    expect(page.motorcycles.single.model, 'MT-07');
  });

  test('no answer, or one it cannot read, is none', () {
    expect(firstPageFromJson(null), isNull);
    expect(firstPageFromJson('not json'), isNull);
    expect(firstPageFromJson('{"listings": []}'), isNull);
    expect(firstPageFromJson('{"listings": [{}], "motorcycles": []}'), isNull);
  });
}
