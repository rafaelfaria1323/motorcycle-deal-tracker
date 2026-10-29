import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/features/settings/data/supabase_push_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/quiet_hours.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SupabasePushRepository repository;
  late List<Request> requests;
  late String body;
  late int status;

  setUp(() {
    requests = [];
    body = '[]';
    status = 200;
    client = SupabaseClient(
      'https://db.example',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          body,
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabasePushRepository(client);
  });

  tearDown(() => client.dispose());

  test('no row means the default quiet hours, 23:00 to 08:00', () async {
    expect(await repository.quietHours(), QuietHours.standard);
    expect(QuietHours.standard.enabled, isTrue);
    expect(requests.single.url.path, '/rest/v1/quiet_hours');
  });

  test('the account\'s own quiet hours are read', () async {
    body = '[{"enabled":false,"start_hour":22,"end_hour":7}]';
    expect(
      await repository.quietHours(),
      const QuietHours(enabled: false, startHour: 22, endHour: 7),
    );
  });

  test('a failed read is an error, not the default', () async {
    status = 503;
    body = '{"code":"unavailable","message":"Database unavailable"}';
    await expectLater(
      repository.quietHours(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('saving upserts the signed-in account\'s row', () async {
    body = '';
    status = 201;
    await repository.saveQuietHours(
      const QuietHours(enabled: true, startHour: 0, endHour: 9),
    );
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/quiet_hours');
    expect(request.url.queryParameters['on_conflict'], 'user_id');
    expect(request.headers['Prefer'], contains('resolution=merge-duplicates'));
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    expect(sent, containsPair('enabled', true));
    expect(sent, containsPair('start_hour', 0));
    expect(sent, containsPair('end_hour', 9));
    expect(sent.containsKey('user_id'), isFalse);
  });
}
