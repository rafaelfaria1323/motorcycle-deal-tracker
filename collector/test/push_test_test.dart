import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store({this.requester});

  final String? requester;
  (String, DateTime)? asked;
  Map<String, dynamic>? listing;
  String? sampleFor;
  Map<String, List<PushTarget>> devices = const {};
  List<String> forgotten = const [];
  List<String> used = const [];
  Map<String, NotificationLanguage> languages = const {};

  @override
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async => {
    for (final user in userIds)
      user: languages[user] ?? NotificationLanguage.portuguese,
  };

  @override
  Future<String?> lastWorkflowStarter(String workflow, DateTime since) async {
    asked = (workflow, since);
    return requester;
  }

  @override
  Future<Map<String, dynamic>?> sampleListing(String? userId) async {
    sampleFor = userId;
    return listing;
  }

  @override
  Future<List<String>> adminIds() async => ['admin1', 'admin2'];

  @override
  Future<Map<String, List<PushTarget>>> pushTargets() async => devices;

  @override
  Future<void> forgetPushTargets(List<String> endpoints) async =>
      forgotten = endpoints;

  @override
  Future<void> markPushTargetsUsed(List<String> endpoints) async =>
      used = endpoints;

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

const _devices = {
  'u1': [PushTarget(endpoint: 'https://p/u1', p256dh: 'k', auth: 'a')],
  'admin1': [PushTarget(endpoint: 'https://p/a1', p256dh: 'k', auth: 'a')],
  'admin2': [PushTarget(endpoint: 'https://p/a2', p256dh: 'k', auth: 'a')],
};

void main() {
  test("asked from the app: only the asking account's devices", () async {
    final store = _Store(requester: 'u1')..devices = _devices;
    final push = _Push();
    final now = DateTime.utc(2026, 10, 21, 15);

    final result = await sendTestPush(store, push, now: now);

    expect(result, (devices: 1, sent: 1));
    expect(store.asked, ('push-test.yml', DateTime.utc(2026, 10, 21, 14, 30)));
    expect(push.sent.single.$1, 'https://p/u1');
    expect(push.sent.single.$2, testPushMessage());
    expect(store.used, ['https://p/u1']);
  });

  test('started elsewhere: every admin\'s devices', () async {
    final store = _Store()..devices = _devices;
    final push = _Push({'https://p/a2': PushResult.gone});

    final result = await sendTestPush(store, push);

    expect(result, (devices: 2, sent: 1));
    expect(store.used, ['https://p/a1']);
    expect(store.forgotten, ['https://p/a2']);
  });

  test(
    'mixed-language admins receive their own test and health copy',
    () async {
      final store = _Store()
        ..devices = _devices
        ..languages = {'admin2': NotificationLanguage.english};
      for (final kind in [
        'test',
        'run_failed',
        'run_blocked',
        'run_recovered',
      ]) {
        final push = _Push();
        expect(await sendTestPush(store, push, kind: kind), (
          devices: 2,
          sent: 2,
        ));
        expect(push.sent.first.$2['language'], 'pt');
        expect(push.sent.last.$2['language'], 'en');
        expect(push.sent.last.$2['title'], isNot(push.sent.first.$2['title']));
        expect(push.sent.first.$2['tag'], push.sent.last.$2['tag']);
        expect(push.sent.first.$2['url'], push.sent.last.$2['url']);
      }
    },
  );

  test('no device: nothing is sent', () async {
    final store = _Store(requester: 'u2')
      ..devices = {
        'u1': [_device('https://p/u1')],
      };
    final push = _Push();

    expect(await sendTestPush(store, push), (devices: 0, sent: 0));
    expect(push.sent, isEmpty);
  });

  test('the test notification opens Mais', () {
    expect(testPushMessage()['url'], '/#/more');
    expect(testPushMessage()['title'], 'Notificação de teste');
  });

  group('examples of each notification', () {
    const listing = {
      'id': 'l1',
      'brand': 'Honda',
      'model': 'CB650R',
      'url': 'https://www.olx.pt/d/anuncio/x',
      'year': 2022,
      'mileage': 8000,
      'price': 7000,
      'deal_score': 81,
      'location': 'Porto',
    };

    test('the asking account (the workflow input) gets the kind it chose, '
        'on one of its listings', () async {
      final store = _Store(requester: 'someone else')
        ..devices = _devices
        ..listing = listing;
      final push = _Push();

      final result = await sendTestPush(
        store,
        push,
        account: 'u1',
        kind: 'price_reduction',
      );

      expect(result, (devices: 1, sent: 1));
      expect(store.asked, isNull);
      expect(store.sampleFor, 'u1');
      final (endpoint, message) = push.sent.single;
      expect(endpoint, 'https://p/u1');
      expect(message, {
        'title': '📉 Baixa de preço: Honda CB650R 2022',
        'body':
            '7 400 € → 7 000 €\n8 000 km · Porto · Pontuação 81\n'
            'Exemplo de teste: nada mudou.',
        'url': '/#/deals/l1',
        'tag': 'push-test',
        'language': 'pt',
      });
    });

    test('each alert type has its own heading and opens the listing', () {
      for (final (kind, heading) in [
        ('new_listing', '🆕 Novo anúncio'),
        ('excellent_opportunity', '🔥 Excelente oportunidade'),
        ('listing_removed', '🚫 Anúncio removido'),
        ('back_on_market', '🔁 Voltou ao mercado'),
        ('target_price_reached', '🎯 Chegou ao seu preço'),
      ]) {
        final m = samplePushMessage(kind, listing);
        expect(m['title'], startsWith(heading), reason: kind);
        expect(m['url'], '/#/deals/l1', reason: kind);
      }
      expect(
        (samplePushMessage('target_price_reached', listing)['body']! as String)
            .split('\n')
            .first,
        '7 000 € (o seu preço: 7 150 €)',
      );
    });

    test('without a listing, an example bike that opens Ofertas', () {
      final m = samplePushMessage('new_listing', null);
      expect(m['title'], '🆕 Novo anúncio: Yamaha MT-07 2021');
      expect(m['url'], '/#/deals');
    });

    test('the collection\'s health opens Estado da recolha', () {
      for (final kind in ['run_failed', 'run_blocked', 'run_recovered']) {
        final m = samplePushMessage(kind, null);
        expect(m['url'], '/#/collection-status', reason: kind);
        expect(m['body'], endsWith('Exemplo de teste: nada mudou.'));
      }
      expect(
        samplePushMessage('run_failed', null)['body'],
        startsWith('olx: Failed: TimeoutException (exemplo)'),
      );
      expect(
        samplePushMessage('run_recovered', null)['title'],
        '✅ A recolha de anúncios voltou a funcionar.',
      );
    });

    test('the test kind, or an unknown one, is the test notification', () {
      expect(samplePushMessage('test', listing), testPushMessage());
      expect(samplePushMessage('nope', listing), testPushMessage());
    });
  });
}
