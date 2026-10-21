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

  @override
  Future<List<PendingAlert>> pendingNotifications({int limit = 20}) async =>
      pending;

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

/// Sends until [failAt] messages went out, then fails.
class _Notifier implements TelegramNotifier {
  _Notifier({this.failAt});

  final int? failAt;
  final sent = <String>[];

  @override
  Future<void> send(String text, {bool linkPreview = true}) async {
    if (sent.length == failAt) throw const NotifyFailed('HTTP 502');
    sent.add(text);
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

PendingAlert _withId(String id, {String user = 'u1'}) => PendingAlert(
  alertId: id,
  userId: user,
  listingId: 'l-$id',
  type: 'new_listing',
  brand: 'Yamaha',
  model: 'R7',
  url: 'https://www.olx.pt/d/anuncio/$id.html',
);

void main() {
  test('every pending alert is sent and marked', () async {
    final store = _Store([_withId('a'), _withId('b')]);
    final notifier = _Notifier();

    expect((await notifyPending(store, telegram: notifier)).alerts, 2);
    expect(notifier.sent, hasLength(2));
    expect(store.notified, ['a', 'b']);
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

  test('a failed send stops; only what went out is marked', () async {
    final store = _Store([_withId('a'), _withId('b'), _withId('c')]);

    expect(
      (await notifyPending(store, telegram: _Notifier(failAt: 1))).alerts,
      1,
    );
    expect(store.notified, ['a']);
  });

  test('euros groups thousands', () {
    expect(euros(6800), '6 800 €');
    expect(euros(12500.4), '12 500 €');
    expect(euros(950), '950 €');
    expect(euros(-123), '-123 €');
    expect(euros(-1234), '-1 234 €');
  });

  test('a new listing shows price, facts, score and link', () {
    expect(
      formatAlert(alert('new_listing', newPrice: 6800)),
      '🆕 Novo anúncio: Yamaha MT-07 2024\n'
      '6 800 €\n'
      '5 000 km · Viseu · Pontuação 87\n'
      'https://www.standvirtual.com/motos/anuncio/x.html',
    );
  });

  test('a price drop shows old and new price', () {
    final text = formatAlert(
      alert('price_reduction', oldPrice: 7200, newPrice: 6800),
    );
    expect(text.split('\n')[1], '7 200 € → 6 800 €');
  });

  test('back on the market shows the new price and the earlier one', () {
    final text = formatAlert(
      alert('back_on_market', oldPrice: 7200, newPrice: 6800),
    );
    expect(text.split('\n')[0], '🔁 Voltou ao mercado: Yamaha MT-07 2024');
    expect(text.split('\n')[1], '6 800 € (antes 7 200 €)');
  });

  test('a target price reached shows the price and the target', () {
    final text = formatAlert(
      alert('target_price_reached', oldPrice: 6600, newPrice: 6500),
    );
    expect(text.split('\n')[0], '🎯 Chegou ao seu preço: Yamaha MT-07 2024');
    expect(text.split('\n')[1], '6 500 € (o seu preço: 6 600 €)');
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
    final text = formatAlert(alert('listing_removed', newPrice: 6800));
    expect(text, isNot(contains('Pontuação')));
  });
}
