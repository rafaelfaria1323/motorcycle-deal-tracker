import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_alerts_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabaseAlertsRepository repository;
  late List<http.Request> requests;
  late bool fail;

  setUp(() {
    requests = [];
    fail = false;
    client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response(
            '{"code":"P0002","message":"Alert not found"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            request: request,
            headers: {'content-range': '*/3'},
          );
        }
        if (request.url.path.endsWith('/dismiss_read_alerts')) {
          return http.Response(
            '2',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          request.method == 'GET' ? '[]' : '',
          request.method == 'GET' ? 200 : 204,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = SupabaseAlertsRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'a page of undismissed alerts, newest first, in a stable order',
    () async {
      expect(await repository.getPage(limit: 40), isEmpty);
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/alerts');
      final query = request.url.queryParameters;
      expect(query['dismissed_at'], 'is.null');
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(query['offset'], '0');
      expect(query['limit'], '40');
      expect(query.containsKey('type'), isFalse);
      expect(query['select'], contains('saved_searches(name)'));
    },
  );

  test('a later page of one kind asks only for its types', () async {
    await repository.getPage(
      limit: 40,
      offset: 80,
      types: {AlertType.listingRemoved},
    );
    final query = requests.single.url.queryParameters;
    expect(query['type'], 'in.(listing_removed)');
    expect(query['offset'], '80');
    expect(query['limit'], '40');
  });

  test('the unread count is a head request without rows', () async {
    expect(await repository.countUnread(), 3);
    final request = requests.single;
    expect(request.method, 'HEAD');
    expect(request.url.path, '/rest/v1/alerts');
    expect(request.url.queryParameters['read_at'], 'is.null');
    expect(request.url.queryParameters['dismissed_at'], 'is.null');
    expect(request.headers['Prefer'], contains('count=exact'));
  });

  test('deleting the read alerts is one RPC that says how many', () async {
    expect(await repository.dismissRead(), 2);
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/rpc/dismiss_read_alerts');
  });

  test('dismissal uses the owner-checked RPC, never table deletion', () async {
    await repository.dismiss('alert-1');
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/rpc/dismiss_alert');
    expect(jsonDecode(request.body), {'p_alert': 'alert-1'});
  });

  test('a refused dismissal is surfaced to the cubit', () async {
    fail = true;
    await expectLater(
      repository.dismiss('missing'),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          'P0002',
        ),
      ),
    );
  });

  test('read actions still update only their permitted column', () async {
    await repository.markRead('alert-1');
    await repository.markAllRead();
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/alerts');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys, ['read_at']);
      expect(DateTime.parse(body['read_at'] as String).isUtc, isTrue);
    }
    expect(requests[0].url.queryParameters['id'], 'eq.alert-1');
    expect(requests[1].url.queryParameters['read_at'], 'is.null');
  });
}
