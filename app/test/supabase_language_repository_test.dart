import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/settings/data/supabase_language_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late SharedPreferences preferences;
  late SupabaseLanguageRepository repository;
  late List<Request> requests;
  late String body;
  late int status;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'account_language:existing-account': 'pt',
    });
    preferences = await SharedPreferences.getInstance();
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
    repository = SupabaseLanguageRepository(client, preferences);
  });

  tearDown(() => client.dispose());

  test('device and account caches do not leak into a new account', () {
    expect(repository.cached(null), AppLanguage.english);
    expect(repository.cached('existing-account'), AppLanguage.portuguese);
    expect(repository.cached('new-account'), AppLanguage.portuguese);
    expect(requests, isEmpty);
  });

  test(
    'remembering an account updates only its cache and the device',
    () async {
      await repository.remember('existing-account', AppLanguage.english);
      expect(repository.cached('existing-account'), AppLanguage.english);
      expect(repository.cached(null), AppLanguage.english);
      expect(repository.cached('new-account'), AppLanguage.portuguese);
      expect(preferences.getString('account_language:existing-account'), 'en');

      await repository.remember(null, AppLanguage.portuguese);
      expect(repository.cached(null), AppLanguage.portuguese);
      expect(repository.cached('existing-account'), AppLanguage.english);
      expect(requests, isEmpty);
    },
  );

  test('a corrupt cache is reported, not silently replaced', () async {
    await preferences.setString('app_language', 'es');
    expect(() => repository.cached(null), throwsFormatException);
  });

  test('loads the explicitly requested account only', () async {
    body = '[{"language":"en"}]';
    expect(await repository.load('existing-account'), AppLanguage.english);
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/rest/v1/account_languages');
    expect(request.url.queryParameters['select'], 'language');
    expect(request.url.queryParameters['user_id'], 'eq.existing-account');
  });

  test(
    'a missing preference means Portuguese, not the device language',
    () async {
      expect(await repository.load('new-account'), AppLanguage.portuguese);
    },
  );

  test('remote failures are distinct from a missing preference', () async {
    status = 503;
    body = '{"code":"unavailable","message":"Database unavailable"}';
    await expectLater(
      repository.load('existing-account'),
      throwsA(isA<PostgrestException>()),
    );
    expect(repository.cached(null), AppLanguage.english);
  });

  test('an unsupported remote language is reported', () async {
    body = '[{"language":"es"}]';
    await expectLater(
      repository.load('existing-account'),
      throwsFormatException,
    );
  });

  test('upserts the captured account and supported language code', () async {
    body = '';
    status = 201;
    await repository.save('existing-account', AppLanguage.english);
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/account_languages');
    expect(request.url.queryParameters['on_conflict'], 'user_id');
    expect(request.headers['Prefer'], contains('resolution=merge-duplicates'));
    expect(jsonDecode(request.body), {
      'user_id': 'existing-account',
      'language': 'en',
    });
    expect(repository.cached('existing-account'), AppLanguage.portuguese);
  });

  test('a failed remote save does not claim a cached change', () async {
    status = 403;
    body = '{"code":"42501","message":"Permission denied"}';
    await expectLater(
      repository.save('existing-account', AppLanguage.english),
      throwsA(isA<PostgrestException>()),
    );
    expect(repository.cached('existing-account'), AppLanguage.portuguese);
  });
}
