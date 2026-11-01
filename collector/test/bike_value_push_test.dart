import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store(this.answers);

  final List<BikeValueAnswer> answers;
  DateTime? askedSince;
  List<String> used = const [];
  Map<String, NotificationLanguage> languages = const {};

  @override
  Future<List<BikeValueAnswer>> answerBikeValues(DateTime startedAt) async {
    askedSince = startedAt;
    return answers;
  }

  @override
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async => {
    for (final user in userIds)
      user: languages[user] ?? NotificationLanguage.portuguese,
  };

  @override
  Future<Map<String, List<PushTarget>>> pushTargets() async => {
    'u1': [const PushTarget(endpoint: 'https://p/u1', p256dh: 'k', auth: 'a')],
    'u2': [const PushTarget(endpoint: 'https://p/u2', p256dh: 'k', auth: 'a')],
  };

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async {}

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async =>
      used = [...used, ...endpoints];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push implements WebPushSender {
  final sent = <(String, Map<String, Object?>)>[];

  @override
  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    sent.add((target.endpoint, message));
    return PushResult.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _z650 = BikeValueAnswer(
  id: 'r1',
  userId: 'u1',
  brand: 'Kawasaki',
  model: 'Z650',
  year: 2019,
  mileage: 30000,
  comparableCount: 12,
  fairPrice: 5249.6,
);

void main() {
  group('bikeValuePush', () {
    test('the bike and its value; a tap opens the request', () {
      expect(bikeValuePush(_z650), {
        'title': '💶 Já sabemos quanto vale a sua mota',
        'body':
            'Kawasaki Z650 2019 30 000 km\nCerca de 5 250 € (de 12 anúncios)',
        'url': '/#/worth?request=r1',
        'tag': 'bike-value-r1',
        'language': 'pt',
      });
    });

    test('in English, one listing, no mileage', () {
      const one = BikeValueAnswer(
        id: 'r2',
        userId: 'u1',
        brand: 'Honda',
        model: 'Forza 350',
        year: 2022,
        comparableCount: 1,
        fairPrice: 4100,
      );
      expect(
        bikeValuePush(one, language: NotificationLanguage.english)['body'],
        'Honda Forza 350 2022\nAbout €4,100 (from 1 listing)',
      );
    });

    test('too few listings: says so instead of a price', () {
      const none = BikeValueAnswer(
        id: 'r3',
        userId: 'u1',
        brand: 'Ducati',
        model: 'Monster',
        year: 2015,
        comparableCount: 0,
      );
      expect(
        bikeValuePush(none)['body'],
        'Ducati Monster 2015\n'
        'Ainda não há anúncios suficientes para uma estimativa.',
      );
    });
  });

  group('answerBikeValues', () {
    test('each answer goes to its own account, in its language', () async {
      final store = _Store([
        _z650,
        const BikeValueAnswer(
          id: 'r9',
          userId: 'u2',
          brand: 'Yamaha',
          model: 'MT-09',
          year: 2021,
          comparableCount: 7,
          fairPrice: 8000,
        ),
      ])..languages = {'u2': NotificationLanguage.english};
      final push = _Push();
      final started = DateTime.utc(2026, 10, 28, 8);

      final result = await answerBikeValues(store, push, started);

      expect(result, (answered: 2, sent: 2));
      expect(store.askedSince, started);
      expect(push.sent.map((s) => s.$1), ['https://p/u1', 'https://p/u2']);
      expect(push.sent.last.$2['title'], "💶 Your bike's value is ready");
      expect(store.used, ['https://p/u1', 'https://p/u2']);
    });

    test('without Web Push the answers still count, none sent', () async {
      final store = _Store([_z650]);
      expect(await answerBikeValues(store, null, DateTime.utc(2026)), (
        answered: 1,
        sent: 0,
      ));
    });
  });

  test('the store asks the database with the run start', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Object? body;
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/rpc/answer_bike_value_requests');
      body = jsonDecode(await utf8.decodeStream(request));
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': 'r1',
              'user_id': 'u1',
              'brand': 'Kawasaki',
              'model': 'Z650',
              'year': 2019,
              'mileage': null,
              'comparable_count': 4,
              'fair_price': 5100.5,
            },
          ]),
        );
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final answers = await PushStore(client)
        .answerBikeValues(DateTime.utc(2026, 10, 28, 8));

    expect(body, {'p_started_at': '2026-10-28T08:00:00.000Z'});
    final a = answers.single;
    expect(
      (a.id, a.userId, a.year, a.mileage, a.comparableCount, a.fairPrice),
      ('r1', 'u1', 2019, null, 4, 5100.5),
    );
  });
}
