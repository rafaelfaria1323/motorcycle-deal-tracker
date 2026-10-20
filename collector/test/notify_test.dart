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

  @override
  Future<List<PendingAlert>> pendingNotifications({int limit = 20}) async =>
      pending;

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

PendingAlert _withId(String id) => PendingAlert(
  alertId: id,
  type: 'new_listing',
  brand: 'Yamaha',
  model: 'R7',
  url: 'https://www.olx.pt/d/anuncio/$id.html',
);

void main() {
  test('every pending alert is sent and marked', () async {
    final store = _Store([_withId('a'), _withId('b')]);
    final notifier = _Notifier();

    expect(await notifyPending(store, notifier), 2);
    expect(notifier.sent, hasLength(2));
    expect(store.notified, ['a', 'b']);
  });

  test('a failed send stops; only what went out is marked', () async {
    final store = _Store([_withId('a'), _withId('b'), _withId('c')]);

    expect(await notifyPending(store, _Notifier(failAt: 1)), 1);
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

  test('a removed listing shows no score', () {
    final text = formatAlert(alert('listing_removed', newPrice: 6800));
    expect(text, isNot(contains('Pontuação')));
  });
}
