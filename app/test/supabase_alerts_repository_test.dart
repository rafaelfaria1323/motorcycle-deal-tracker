import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/repositories/supabase_alerts_repository.dart';
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

  test('only undismissed alerts are loaded, newest first', () async {
    expect(await repository.getAll(), isEmpty);
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/rest/v1/alerts');
    expect(request.url.queryParameters['dismissed_at'], 'is.null');
    expect(request.url.queryParameters['order'], 'created_at.desc.nullslast');
    expect(request.url.queryParameters['limit'], '100');
    expect(
      request.url.queryParameters['select'],
      contains('saved_searches(name)'),
    );
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
