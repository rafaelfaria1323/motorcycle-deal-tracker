import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late ListingStore store;
  late List<Uri> requests;
  late List<Map<String, String>> rows;
  late int status;
  late bool lastBatchOnly;

  setUp(() async {
    requests = [];
    rows = [];
    status = 200;
    lastBatchOnly = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      expect(request.method, 'GET');
      expect(request.uri.path, '/rest/v1/account_languages');
      expect(request.uri.queryParameters['select'], 'user_id,language');
      final result =
          lastBatchOnly &&
              !request.uri.queryParameters['user_id']!.contains('u100')
          ? const <Map<String, String>>[]
          : rows;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(
            status == 200
                ? result
                : {'code': '42501', 'message': 'Preference lookup refused'},
          ),
        );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    store = ListingStore(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('only missing preferences default to Portuguese', () async {
    rows = [
      {'user_id': 'b', 'language': 'en'},
    ];
    expect(await store.accountLanguages(['a', 'b', 'a']), {
      'a': NotificationLanguage.portuguese,
      'b': NotificationLanguage.english,
    });
    expect(requests, hasLength(1));
    expect(
      requests.single.queryParameters['user_id'],
      allOf(startsWith('in.('), contains('a'), contains('b')),
    );
  });

  test('empty recipients require no query', () async {
    expect(await store.accountLanguages([]), isEmpty);
    expect(requests, isEmpty);
  });

  test('large recipient lists use bounded complete batches', () async {
    lastBatchOnly = true;
    rows = [
      {'user_id': 'u100', 'language': 'en'},
    ];
    final users = List.generate(101, (index) => 'u$index');
    final languages = await store.accountLanguages([...users, 'u100']);
    expect(requests, hasLength(2));
    expect(languages, hasLength(101));
    expect(languages['u99'], NotificationLanguage.portuguese);
    expect(languages['u100'], NotificationLanguage.english);
    expect(requests.first.queryParameters['user_id'], isNot(contains('u100')));
    expect(requests.last.queryParameters['user_id'], contains('u100'));
  });

  test('a query failure cannot become a Portuguese preference', () async {
    status = 403;
    await expectLater(
      store.accountLanguages(['a']),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('an unsupported stored language fails explicitly', () async {
    rows = [
      {'user_id': 'a', 'language': 'es'},
    ];
    await expectLater(store.accountLanguages(['a']), throwsFormatException);
  });
}
