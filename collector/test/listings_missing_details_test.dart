import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late List<Object?> bodies;

  setUp(() async {
    bodies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/rpc/listings_missing_details');
      bodies.add(jsonDecode(await utf8.decodeStream(request)));
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {'source_listing_id': 'fav', 'url': 'https://x/fav'},
            {'source_listing_id': 'new', 'url': 'https://x/new'},
          ]),
        );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('the database decides the order; the rows keep it', () async {
    final store = ListingStore(client);
    final pending = await store.listingsMissingDetails('standvirtual', 10);
    expect(pending.map((p) => p.sourceListingId), ['fav', 'new']);
    expect(pending.first.url, 'https://x/fav');
    expect(bodies.single, {'p_source': 'standvirtual', 'p_limit': 10});

    await store.listingsMissingDetails('standvirtual', null);
    expect(bodies.last, {'p_source': 'standvirtual', 'p_limit': null});
  });
}
