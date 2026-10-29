import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// The database's answers and each account's devices, in memory.
class _Exams implements ListingStore {
  _Exams(this.answers);

  final List<PhotoExamAnswer> answers;
  List<String>? askedFor;

  @override
  Future<List<PhotoExamAnswer>> photoExamAnswers(List<String> ids) async {
    askedFor = ids;
    return answers;
  }

  @override
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async => {
    for (final user in userIds)
      user: user == 'en'
          ? NotificationLanguage.english
          : NotificationLanguage.portuguese,
  };

  @override
  Future<Map<String, List<PushTarget>>> pushTargets() async => {
    for (final user in ['pt', 'en'])
      user: [PushTarget(endpoint: 'fcm:$user', p256dh: '', auth: '')],
  };

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async {}

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Takes every push; remembers each device's message.
class _Devices implements WebPushSender {
  final messages = <String, Map<String, Object?>>{};

  @override
  Future<PushResult> send(PushTarget target, Map<String, Object?> m) async {
    messages[target.endpoint] = m;
    return PushResult.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PhotoExamAnswer _answer(String user, {int hints = 0, int? year = 2020}) =>
    PhotoExamAnswer(
      userId: user,
      listingId: 'l-$user',
      brand: 'Yamaha',
      model: 'MT-07',
      year: year,
      hints: hints,
    );

void main() {
  group('photoExamPush', () {
    test('the bike and its hints; a tap opens the listing', () {
      expect(photoExamPush(_answer('pt', hints: 2)), {
        'title': '📷 Todas as fotos foram examinadas',
        'body': 'Yamaha MT-07 2020\n2 pistas nas fotos: veja a Avaliação.',
        'url': '/#/deals/l-pt',
        'tag': 'photo-exam-l-pt',
        'language': 'pt',
      });
    });

    test('no hint, one hint, in English, no year', () {
      expect(
        photoExamPush(_answer('pt', year: null))['body'],
        'Yamaha MT-07\nNenhuma pista de problemas nas fotos.',
      );
      expect(
        photoExamPush(_answer('pt', hints: 1))['body'],
        'Yamaha MT-07 2020\n1 pista nas fotos: veja a Avaliação.',
      );
      final english = photoExamPush(
        _answer('en', hints: 1),
        language: NotificationLanguage.english,
      );
      expect(english['title'], '📷 Every photo was examined');
      expect(
        english['body'],
        'Yamaha MT-07 2020\n1 hint in the photos: see the Assessment.',
      );
      expect(
        photoExamPush(
          _answer('en'),
          language: NotificationLanguage.english,
        )['body'],
        'Yamaha MT-07 2020\nNo hint of problems in the photos.',
      );
    });
  });

  group('tellPhotoExams', () {
    test('each asker on its devices, in its language', () async {
      final store = _Exams([_answer('pt'), _answer('en', hints: 3)]);
      final devices = _Devices();

      expect(await tellPhotoExams(store, devices, ['l-pt', 'l-en']), 2);
      expect(store.askedFor, ['l-pt', 'l-en']);
      expect(devices.messages.keys, ['fcm:pt', 'fcm:en']);
      expect(devices.messages['fcm:en']!['language'], 'en');
    });

    test('nothing finished: the database is not asked', () async {
      final store = _Exams([_answer('pt')]);
      expect(await tellPhotoExams(store, _Devices(), const []), 0);
      expect(store.askedFor, isNull);
    });
  });

  test('the store reads photo_exam_answers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Object? asked;
    server.listen((request) async {
      expect(request.uri.path, '/rest/v1/rpc/photo_exam_answers');
      asked = jsonDecode(await utf8.decodeStream(request));
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'user_id': 'u1',
              'listing_id': 'l1',
              'brand': 'Honda',
              'model': 'CB650R',
              'year': null,
              'hints': 1,
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

    final answer = (await ListingStore(client).photoExamAnswers(['l1'])).single;

    expect(asked, {
      'p_listings': ['l1'],
    });
    expect(
      (
        answer.userId,
        answer.listingId,
        answer.model,
        answer.year,
        answer.hints,
      ),
      ('u1', 'l1', 'CB650R', null, 1),
    );
  });
}
