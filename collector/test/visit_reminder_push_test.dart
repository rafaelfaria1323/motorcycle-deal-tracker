import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store(this.visits, {this.devices = const {}});

  final List<VisitReminder> visits;
  final Map<String, List<PushTarget>> devices;
  final marked = <String>[];
  DateTime? askedAt;

  @override
  Future<List<VisitReminder>> pendingVisitReminders(DateTime at) async {
    askedAt = at;
    return visits;
  }

  @override
  Future<void> markVisitReminded(VisitReminder visit) async =>
      marked.add(visit.listingId);

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

VisitReminder _visit({
  String user = 'u1',
  String listing = 'l1',
  int day = 1,
  bool live = true,
  double? price = 6500,
  String? location = 'Lisboa',
}) => VisitReminder(
  userId: user,
  listingId: listing,
  visitAt: DateTime.utc(2026, 11, 13, 10),
  day: day,
  time: '10:00',
  brand: 'Yamaha',
  model: 'MT-07',
  year: 2021,
  price: price,
  location: location,
  live: live,
);

PushTarget _device(String endpoint) =>
    PushTarget(endpoint: endpoint, p256dh: 'k', auth: 'a');

void main() {
  group('the reminder', () {
    test('tomorrow, the bike and the checklist; a tap opens the ad', () {
      expect(visitReminderPush(_visit()), {
        'title': '📍 Visita amanhã às 10:00',
        'body':
            'Yamaha MT-07 2021 · 6 500 € · Lisboa\n'
            'Leve a lista «Para a visita»: está no anúncio.',
        'url': '/#/deals/l1',
        'tag': 'visit-l1',
        'language': 'pt',
      });
    });

    test('today, in English, without price or place', () {
      final message = visitReminderPush(
        _visit(day: 0, price: null, location: ''),
        language: .english,
      );
      expect(message['title'], '📍 Viewing today at 10:00');
      expect(
        message['body'],
        'Yamaha MT-07 2021\n'
        "Take the viewing checklist with you: it's on the listing.",
      );
    });

    test('further away, and an ad already gone', () {
      expect(
        visitReminderPush(_visit(day: 2))['title'],
        '📍 Visita daqui a 2 dias, às 10:00',
      );
      expect(
        visitReminderPush(_visit(day: 3), language: .english)['title'],
        '📍 Viewing in 3 days, at 10:00',
      );
      expect(
        visitReminderPush(_visit(live: false))['body'],
        endsWith('O anúncio já saiu: confirme com o vendedor antes de ir.'),
      );
      expect(
        visitReminderPush(_visit(live: false), language: .english)['body'],
        endsWith('The listing is gone: check with the seller before you go.'),
      );
    });

    test('read from the database row', () {
      final visit = VisitReminder.fromRow({
        'user_id': 'u1',
        'listing_id': 'l1',
        'visit_at': '2026-11-13T10:00:00+00:00',
        'visit_day': 1,
        'visit_time': '10:00',
        'brand': 'Honda',
        'model': 'CB650R',
        'year': null,
        'price': 7200.5,
        'location': null,
        'is_live': false,
      });
      expect(
        (
          visit.visitAt,
          visit.day,
          visit.time,
          visit.year,
          visit.price,
          visit.location,
          visit.live,
        ),
        (DateTime.utc(2026, 11, 13, 10), 1, '10:00', null, 7200.5, null, false),
      );
    });
  });

  group('remindVisits', () {
    test('each owner in its language; sent ones are marked', () async {
      final store = _Store(
        [_visit(), _visit(user: 'en', listing: 'l2')],
        devices: {
          'u1': [_device('https://p/u1')],
          'en': [_device('https://p/en')],
        },
      );
      final push = _Push();
      final at = DateTime.utc(2026, 11, 12, 10);

      expect(await remindVisits(store, push, at), (reminded: 2, sent: 2));
      expect(store.askedAt, at);
      expect(store.marked, ['l1', 'l2']);
      expect(push.sent.map((m) => m['language']), ['pt', 'en']);
    });

    test('no device: marked, nothing to wait for', () async {
      final store = _Store([_visit()]);
      expect(await remindVisits(store, _Push(), DateTime.utc(2026)), (
        reminded: 1,
        sent: 0,
      ));
      expect(store.marked, ['l1']);
    });

    test('every device failed: tried again by the next run', () async {
      final store = _Store(
        [_visit()],
        devices: {
          'u1': [_device('https://p/a'), _device('https://p/b')],
        },
      );
      final push = _Push(failing: {'https://p/a', 'https://p/b'});
      expect(await remindVisits(store, push, DateTime.utc(2026)), (
        reminded: 0,
        sent: 0,
      ));
      expect(store.marked, isEmpty);
    });

    test('one device took it: marked', () async {
      final store = _Store(
        [_visit()],
        devices: {
          'u1': [_device('https://p/a'), _device('https://p/b')],
        },
      );
      final push = _Push(failing: {'https://p/a'});
      expect(await remindVisits(store, push, DateTime.utc(2026)), (
        reminded: 1,
        sent: 1,
      ));
      expect(store.marked, ['l1']);
    });

    test('without Web Push nothing is read: they wait', () async {
      final store = _Store([_visit()]);
      expect(await remindVisits(store, null, DateTime.utc(2026)), (
        reminded: 0,
        sent: 0,
      ));
      expect(store.askedAt, isNull);
    });
  });

  group('the push test example', () {
    test('on a live listing, opening it', () {
      final message = samplePushMessage('visit_reminder', {
        'id': 'abc',
        'brand': 'Honda',
        'model': 'CB650R',
        'year': 2020,
        'price': 7200,
        'location': 'Porto',
      });
      expect(message['title'], '📍 Visita amanhã às 10:00');
      expect(
        message['body'],
        startsWith('Honda CB650R 2020 · 7 200 € · Porto\n'),
      );
      expect(message['url'], '/#/deals/abc');
      expect(message['tag'], 'push-test');
    });

    test('without one, the example bike opens Ofertas', () {
      final message = samplePushMessage(
        'visit_reminder',
        null,
        language: .english,
      );
      expect(message['title'], '📍 Viewing tomorrow at 10:00');
      expect(
        message['body'],
        startsWith('Yamaha MT-07 2021 · €6,500 · Lisboa\n'),
      );
      expect(message['url'], '/#/deals');
      expect(pushTestKinds, contains('visit_reminder'));
    });
  });
}
