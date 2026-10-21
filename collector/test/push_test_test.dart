import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements ListingStore {
  _Store({this.requester});

  final String? requester;
  (String, DateTime)? asked;
  Map<String, List<PushTarget>> devices = const {};
  List<String> forgotten = const [];
  List<String> used = const [];

  @override
  Future<String?> lastWorkflowStarter(String workflow, DateTime since) async {
    asked = (workflow, since);
    return requester;
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
    expect(push.sent.single, ('https://p/u1', testPushMessage));
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
    expect(testPushMessage['url'], '/#/more');
    expect(testPushMessage['title'], 'Notificação de teste');
  });
}
