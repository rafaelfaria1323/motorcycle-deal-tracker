import 'package:collector/collector.dart';
import 'package:test/test.dart';

class _Store implements PushStore {
  _Store(this.notices, {this.devices = const {}, this.admins = const ['a1']});

  final List<AdminNotice> notices;
  final Map<String, List<PushTarget>> devices;
  final List<String> admins;
  final marked = <int>[];

  @override
  Future<List<AdminNotice>> takeAdminNotices() async => notices;

  @override
  Future<void> markAdminNoticeSent(int id) async => marked.add(id);

  @override
  Future<List<String>> adminIds() async => admins;

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

final _now = DateTime.utc(2026, 11, 16, 12);

AdminNotice _notice(
  String kind, {
  int id = 1,
  Map<String, dynamic> details = const {},
  Duration age = Duration.zero,
}) => AdminNotice(
  id: id,
  kind: kind,
  details: details,
  createdAt: _now.subtract(age),
);

PushTarget _device(String endpoint) =>
    PushTarget(endpoint: endpoint, p256dh: '', auth: '');

void main() {
  test('reads a row of take_admin_notices', () {
    final notice = AdminNotice.fromRow({
      'id': 7,
      'kind': 'listings_pruned',
      'details': {'deleted': 2},
      'created_at': '2026-11-16T03:37:00+00:00',
    });
    expect(notice.id, 7);
    expect(notice.kind, 'listings_pruned');
    expect(notice.details, {'deleted': 2});
    expect(notice.createdAt, DateTime.utc(2026, 11, 16, 3, 37));
    expect(
      AdminNotice.fromRow({
        'id': 1,
        'kind': 'collection_resumed',
        'details': null,
        'created_at': '2026-11-16T03:37:00Z',
      }).details,
      isEmpty,
    );
  });

  group('adminNoticePush', () {
    test('says each kind with its details, in both languages', () {
      final stopped = adminNoticePush(
        _notice(
          'collection_stopped',
          details: {'hours': 10, 'last_run': '16/11 02:00'},
        ),
      );
      expect(stopped['title'], contains('nas últimas 10 h'));
      expect(stopped['body'], startsWith('A última foi a 16/11 02:00.'));
      expect(stopped['url'], '/#/collection-status');
      expect(stopped['tag'], 'admin-collection_stopped');
      expect(stopped['language'], 'pt');

      final english = adminNoticePush(
        _notice('github_token_refused', details: {'http_status': 401}),
        language: .english,
      );
      expect(english['title'], contains('refused'));
      expect(english['title'], endsWith('(HTTP 401)'));
      expect(english['language'], 'en');

      expect(
        adminNoticePush(
          _notice(
            'github_token_expiring',
            details: {'expires_on': '30/11/2026'},
          ),
        )['title'],
        contains('expira a 30/11/2026'),
      );
      final pruned = adminNoticePush(
        _notice('listings_pruned', details: {'deleted': 3, 'database_mb': 401}),
      );
      expect(pruned['title'], contains('3 anúncios'));
      expect(pruned['body'], contains('401 MB'));
      expect(
        adminNoticePush(_notice('collection_resumed'))['title'],
        startsWith('✅'),
      );
    });

    test('lists the tax tables\' differences, then what to update', () {
      final message = adminNoticePush(
        _notice(
          'tax_tables',
          details: {
            'year': 2027,
            'differences': ['ISV 251-350 cc: 91.63 -> 93.00'],
          },
        ),
        language: .english,
      );
      expect(message['title'], contains('2027'));
      expect(
        message['body'],
        'ISV 251-350 cc: 91.63 -> 93.00\n'
        'Update isvBands, iucBands and motorcycle_isv (tool/tax_tables.py).',
      );
    });

    test('missing details read as "?"; an unknown kind is its name', () {
      expect(
        adminNoticePush(_notice('collection_stopped'))['title'],
        contains('últimas ? h'),
      );
      expect(adminNoticePush(_notice('other'))['title'], 'other');
    });
  });

  group('sendAdminNotices', () {
    test('pushes every notice to every admin, then marks it sent', () async {
      final store = _Store(
        [_notice('collection_resumed'), _notice('listings_pruned', id: 2)],
        admins: ['a1', 'en'],
        devices: {
          'a1': [_device('d1')],
          'en': [_device('d2')],
        },
      );
      final push = _Push();
      final result = await sendAdminNotices(store, push, now: _now);
      expect(result, (notices: 2, sent: 4));
      expect(store.marked, [1, 2]);
      expect(push.sent.map((m) => m['language']), ['pt', 'en', 'pt', 'en']);
    });

    test('waits when every device failed, up to a day', () async {
      final store = _Store(
        [
          _notice('collection_resumed'),
          _notice('collection_resumed', id: 2, age: const Duration(hours: 24)),
        ],
        devices: {
          'a1': [_device('d1')],
        },
      );
      final result = await sendAdminNotices(
        store,
        _Push(failing: {'d1'}),
        now: _now,
      );
      expect(result, (notices: 1, sent: 0));
      expect(store.marked, [2], reason: 'a day old: given up');
    });

    test('with no admin device, nothing to wait for', () async {
      final store = _Store([_notice('tax_tables')]);
      expect(await sendAdminNotices(store, _Push(), now: _now), (
        notices: 1,
        sent: 0,
      ));
      expect(store.marked, [1]);
    });

    test('nothing waiting: the admins are not even read', () async {
      final store = _Store(const [], admins: const []);
      expect(await sendAdminNotices(store, _Push()), (notices: 0, sent: 0));
    });
  });
}
