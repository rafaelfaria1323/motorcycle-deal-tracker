import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store(this.notices, {this.devices = const {}});

  final List<RecallNotice> notices;
  final Map<String, List<PushTarget>> devices;
  final marked = <String>[];
  DateTime? askedAt;

  @override
  Future<List<RecallNotice>> pendingRecallNotices(DateTime at) async {
    askedAt = at;
    return notices;
  }

  @override
  Future<void> markRecallNoticed(RecallNotice notice) async =>
      marked.add(notice.caseNumber);

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
  Future<Map<String, List<PushTarget>>> pushTargets() async => devices;

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async {}

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push implements WebPushSender {
  _Push({this.failing = const {}});

  final Set<String> failing;
  final sent = <Map<String, Object?>>[];

  @override
  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    if (failing.contains(target.endpoint)) return PushResult.failed;
    sent.add(message);
    return PushResult.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecallNotice _notice({
  String user = 'u1',
  String caseNumber = 'A12/001',
  String? bike = 'b1',
  String? listing,
  String? dangerEn = 'The brake hose may leak.',
  String? dangerPt = 'O tubo do travão pode verter.',
  String? code = '3P0',
}) => RecallNotice(
  userId: user,
  caseNumber: caseNumber,
  bikeId: bike,
  listingId: listing,
  brand: 'Yamaha',
  model: 'MT-07',
  year: 2021,
  recallName: 'MT-07',
  recallCode: code,
  dangerEn: dangerEn,
  dangerPt: dangerPt,
);

PushTarget _device(String endpoint) =>
    PushTarget(endpoint: endpoint, p256dh: 'k', auth: 'a');

void main() {
  group('the notice', () {
    test(
      'an own bike: the danger, the code, the dealer; opens A minha mota',
      () {
        expect(recallPush(_notice(listing: 'l9')), {
          'title': '⚠️ Recolha na UE: Yamaha MT-07 2021',
          'body':
              'O tubo do travão pode verter.\n'
              'Código da marca: 3P0.\n'
              'Peça a um concessionário da marca que verifique pelo número '
              'de quadro.',
          'url': '/#/my-bike',
          'tag': 'recall-A12/001',
          'language': 'pt',
        });
      },
    );

    test('a favourite in English opens its ad and asks the seller', () {
      final message = recallPush(
        _notice(bike: null, listing: 'l1', code: null),
        language: .english,
      );
      expect(message['title'], '⚠️ EU recall: Yamaha MT-07 2021');
      expect(
        message['body'],
        'The brake hose may leak.\n'
        'Ask the seller whether the recall work was done.',
      );
      expect(message['url'], '/#/deals/l1');
    });

    test('the other language when only it was read; long text shortened', () {
      expect(
        recallPush(_notice(dangerPt: null))['body'],
        startsWith('The brake hose may leak.\n'),
      );
      expect(
        recallPush(_notice(dangerEn: null), language: .english)['body'],
        startsWith('O tubo do travão pode verter.\n'),
      );
      final long =
          recallPush(_notice(dangerPt: 'a' * 300, code: ''))['body'] as String;
      final first = long.split('\n').first;
      expect(first.length, recallDangerMaxLength);
      expect(first, endsWith('…'));
      expect(long.split('\n'), hasLength(2));
      expect(
        recallPush(_notice(dangerEn: null, dangerPt: ' '))['body'],
        startsWith('Código da marca'),
      );
    });

    test('read from the database row', () {
      final notice = RecallNotice.fromRow({
        'user_id': 'u1',
        'case_number': 'A12/001',
        'bike_id': null,
        'listing_id': 'l1',
        'brand': 'Yamaha',
        'model': 'MT-07',
        'year': 2021,
        'recall_name': 'MT-07',
        'recall_code': '3P0',
        'danger_en': 'Leak.',
        'danger_pt': 'Fuga.',
      });
      expect(notice.owned, isFalse);
      expect(notice.listingId, 'l1');
      expect(notice.year, 2021);
      expect(notice.recallName, 'MT-07');
      expect(notice.recallCode, '3P0');
      expect(notice.dangerEn, 'Leak.');
      expect(notice.dangerPt, 'Fuga.');
    });
  });

  group('noticeRecalls', () {
    test('without Web Push nothing is read', () async {
      final store = _Store([_notice()]);
      expect(await noticeRecalls(store, null, DateTime.utc(2026)), (
        noticed: 0,
        sent: 0,
      ));
      expect(store.askedAt, isNull);
    });

    test('sent to each account in its language and marked', () async {
      final at = DateTime.utc(2026, 11, 13, 12);
      final store = _Store(
        [
          _notice(),
          _notice(user: 'en', caseNumber: 'A12/002', bike: null, listing: 'l1'),
        ],
        devices: {
          'u1': [_device('d1')],
          'en': [_device('d2')],
        },
      );
      final push = _Push();
      expect(await noticeRecalls(store, push, at), (noticed: 2, sent: 2));
      expect(store.askedAt, at);
      expect(store.marked, ['A12/001', 'A12/002']);
      expect(push.sent.map((m) => m['language']), ['pt', 'en']);
    });

    test('no device: marked; every device failed: waits', () async {
      final store = _Store(
        [_notice(), _notice(user: 'u2', caseNumber: 'A12/002')],
        devices: {
          'u2': [_device('bad')],
        },
      );
      expect(
        await noticeRecalls(store, _Push(failing: {'bad'}), DateTime.utc(2026)),
        (noticed: 1, sent: 0),
      );
      expect(store.marked, ['A12/001']);
    });
  });

  test('a recall is a test notification kind', () {
    expect(pushTestKinds, contains('recall'));
    final message = samplePushMessage('recall', {
      'id': 'l1',
      'brand': 'Honda',
      'model': 'CB650R',
      'year': 2020,
    });
    expect(message['title'], '⚠️ Recolha na UE: Honda CB650R 2020');
    expect(message['url'], '/#/deals/l1');
    expect(message['tag'], 'push-test');
    expect(samplePushMessage('recall', null)['url'], '/#/deals');
  });
}
