import 'package:collector/collector.dart';
import 'package:test/test.dart';

PendingAlert alert(String type, {double? oldPrice, double? newPrice}) =>
    PendingAlert(
      alertId: 'a1',
      type: type,
      brand: 'Yamaha',
      model: 'MT-07',
      url: 'https://www.standvirtual.com/motos/anuncio/x.html',
      oldPrice: oldPrice,
      newPrice: newPrice,
      year: 2024,
      mileage: 5000,
      price: 6800,
      dealScore: 87,
      location: 'Viseu',
    );

class _Store implements ListingStore {
  _Store(this.pending);

  final List<PendingAlert> pending;
  List<String>? notified;
  Map<String, List<PushTarget>> devices = const {};
  List<String> forgotten = const [];
  List<String> used = const [];
  final summaries = <String, Map<String, Object?>>{};

  @override
  Future<void> saveWeeklySummary(
    String userId,
    WeeklySummary summary,
    Map<String, Object?> json,
  ) async => summaries[userId] = json;

  @override
  Future<List<PendingAlert>> pendingNotifications({int limit = 20}) async {
    limits.add(limit);
    return pending;
  }

  final limits = <int>[];

  @override
  Future<Map<String, List<PushTarget>>> pushTargets() async => devices;

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async =>
      forgotten = endpoints;

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async =>
      used = endpoints;

  @override
  Future<int> markNotified(List<String> alertIds) async {
    notified = alertIds;
    return alertIds.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers each device with [results] (by endpoint; sent otherwise).
class _Push implements WebPushSender {
  _Push([this.results = const {}]);

  final Map<String, PushResult> results;
  final sent = <(String, Map<String, Object?>)>[];

  @override
  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    sent.add((target.endpoint, message));
    return results[target.endpoint] ?? PushResult.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PushTarget _device(String endpoint) =>
    PushTarget(endpoint: endpoint, p256dh: 'k', auth: 'a');

final _now = DateTime.utc(2026, 10, 21, 12);

PendingAlert _withId(
  String id, {
  String user = 'u1',
  Duration age = Duration.zero,
}) => PendingAlert(
  alertId: id,
  createdAt: _now.subtract(age),
  userId: user,
  listingId: 'l-$id',
  type: 'new_listing',
  brand: 'Yamaha',
  model: 'R7',
  url: 'https://www.olx.pt/d/anuncio/$id.html',
);

void main() {
  test('every pending alert is marked, with or without devices', () async {
    final store = _Store([_withId('a'), _withId('b', user: 'u2')])
      ..devices = {
        'u1': [_device('https://p/1')],
      };

    expect(await notifyPending(store, push: _Push()), (alerts: 2, pushes: 1));
    expect(store.notified, ['a', 'b']);
    expect(store.limits, [pendingPerRun]);
  });

  test('without Web Push nothing is marked: the next run sends', () async {
    final store = _Store([_withId('a')]);
    expect(await notifyPending(store), (alerts: 0, pushes: 0));
    expect(store.notified, isNull);
  });

  test('an alert no device got is tried again, for a day', () async {
    final store =
        _Store([
            _withId('fresh'),
            _withId('old', age: const Duration(hours: 25)),
          ])
          ..devices = {
            'u1': [_device('https://p/down')],
          };
    final push = _Push({'https://p/down': PushResult.failed});

    final result = await notifyPending(store, push: push, now: _now);

    expect(result, (alerts: 1, pushes: 0));
    expect(store.notified, ['old']);
    // The old one is old news: not pushed at all.
    expect(push.sent, hasLength(1));
  });

  test('one device failing does not repeat it on the others', () async {
    final store = _Store([_withId('a')])
      ..devices = {
        'u1': [_device('https://p/down'), _device('https://p/up')],
      };
    final push = _Push({'https://p/down': PushResult.failed});

    expect(await notifyPending(store, push: push, now: _now), (
      alerts: 1,
      pushes: 1,
    ));
    expect(store.notified, ['a']);
  });

  test("each alert goes to its own account's devices", () async {
    final store = _Store([_withId('a'), _withId('b', user: 'u2')])
      ..devices = {
        'u1': [_device('https://p/1'), _device('https://p/2')],
        'u2': [_device('https://p/3')],
      };
    final push = _Push();

    final result = await notifyPending(store, push: push);

    expect(result, (alerts: 2, pushes: 3));
    expect(
      [for (final (endpoint, _) in push.sent) endpoint],
      ['https://p/1', 'https://p/2', 'https://p/3'],
    );
    expect(push.sent.last.$2['url'], '/#/deals/l-b');
    expect(
      store.used,
      unorderedEquals(['https://p/1', 'https://p/2', 'https://p/3']),
    );
    expect(store.notified, ['a', 'b']);
  });

  test('a device that no longer exists is forgotten and skipped', () async {
    final store = _Store([_withId('a'), _withId('b')])
      ..devices = {
        'u1': [_device('https://p/old'), _device('https://p/new')],
      };
    final push = _Push({'https://p/old': PushResult.gone});

    final result = await notifyPending(store, push: push);

    expect(result.pushes, 2);
    expect(push.sent.where((s) => s.$1 == 'https://p/old'), hasLength(1));
    expect(store.forgotten, ['https://p/old']);
    expect(store.used, ['https://p/new']);
  });

  test('nothing pending: no device is read', () async {
    final store = _Store([]);
    expect(await notifyPending(store, push: _Push()), (alerts: 0, pushes: 0));
    expect(store.notified, isNull);
  });

  test('euros groups thousands', () {
    expect(euros(6800), '6 800 €');
    expect(euros(12500.4), '12 500 €');
    expect(euros(950), '950 €');
    expect(euros(-123), '-123 €');
    expect(euros(-1234), '-1 234 €');
  });

  test('a new listing shows price, facts and score', () {
    expect(pushMessage(alert('new_listing', newPrice: 6800)), {
      'title': '🆕 Novo anúncio: Yamaha MT-07 2024',
      'body': '6 800 €\n5 000 km · Viseu · Pontuação 87',
      'url': 'https://www.standvirtual.com/motos/anuncio/x.html',
      'tag': 'a1',
    });
  });

  test('back on the market shows the new price and the earlier one', () {
    final message = pushMessage(
      alert('back_on_market', oldPrice: 7200, newPrice: 6800),
    );
    expect(message['title'], '🔁 Voltou ao mercado: Yamaha MT-07 2024');
    expect(message['body'], startsWith('6 800 € (antes 7 200 €)\n'));
  });

  test('a target price reached shows the price and the target', () {
    final message = pushMessage(
      alert('target_price_reached', oldPrice: 6600, newPrice: 6500),
    );
    expect(message['title'], '🎯 Chegou ao seu preço: Yamaha MT-07 2024');
    expect(message['body'], startsWith('6 500 € (o seu preço: 6 600 €)\n'));
  });

  test('the push message opens the listing in the app', () {
    final message = pushMessage(
      PendingAlert(
        alertId: 'a9',
        type: 'price_reduction',
        brand: 'Yamaha',
        model: 'MT-07',
        url: 'https://www.olx.pt/d/anuncio/x.html',
        listingId: 'l9',
        oldPrice: 7200,
        newPrice: 6800,
        year: 2024,
        mileage: 5000,
        location: 'Viseu',
        dealScore: 87,
      ),
    );
    expect(message, {
      'title': '📉 Baixa de preço: Yamaha MT-07 2024',
      'body': '7 200 € → 6 800 €\n5 000 km · Viseu · Pontuação 87',
      'url': '/#/deals/l9',
      'tag': 'a9',
    });
  });

  test('a removed listing shows no score', () {
    final message = pushMessage(alert('listing_removed', newPrice: 6800));
    expect(message['body'], isNot(contains('Pontuação')));
  });

  test('each weekly summary is kept and sent to its own devices', () async {
    final store = _Store([])
      ..devices = {
        'u1': [_device('https://p/1')],
        'u2': [_device('https://p/2')],
      };
    final push = _Push();
    final until = DateTime.utc(2026, 10, 19, 8);
    final week = buildWeeklySummary(
      listings: const [],
      history: const [],
      until: until,
    );

    final result = await sendWeeklySummaries(store, push, {
      'u1': week,
      'u3': week,
    });

    expect(result, (accounts: 2, devices: 1, sent: 1));
    expect(store.summaries.keys, ['u1', 'u3']);
    expect(store.summaries['u1']!['new'], 0);
    expect(push.sent.single.$1, 'https://p/1');
    expect(push.sent.single.$2['url'], '/#/summary');
  });
}
