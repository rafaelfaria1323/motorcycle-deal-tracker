import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_alert_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/alerts_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/alerts_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/alerts_state.dart';

import 'helpers/session_fixture.dart';

late SessionFixture _session;

AlertsCubit _cubit(AlertsRepository repository) =>
    _session.track(AlertsCubit(repository, _session.cubit));

Map<String, dynamic> _row(String id, {String? readAt}) => {
  'id': id,
  'type': 'new_listing',
  'new_price': 7400,
  'old_price': null,
  'read_at': readAt,
  'created_at': '2026-10-18T20:00:00Z',
  'saved_search_id': 'search-1',
  'saved_searches': {'name': 'MT-07 barata'},
  'listings': {
    'id': 'l-$id',
    'source': 'manual',
    'url': 'https://example.com/x',
    'brand': 'Yamaha',
    'model': 'MT-07',
    'year': 2026,
    'price': 7400,
    'seller_type': 'dealer',
    'status': 'active',
    'images': <String>[],
    'first_seen_at': '2026-10-18T19:00:00Z',
    'last_seen_at': '2026-10-18T19:00:00Z',
  },
};

class _FakeAlerts implements AlertsRepository {
  _FakeAlerts(
    this.items, {
    this.failMarkRead = false,
    this.failDismiss = false,
  });

  final List<ListingAlert> items;
  bool failMarkRead;
  final bool failDismiss;
  final marked = <String>[];
  final dismissed = <String>{};
  Future<void>? readDelay;
  Future<void>? dismissDelay;
  Future<List<ListingAlert>>? loadResult;
  bool failLoad = false;

  @override
  Future<List<ListingAlert>> getAll() async {
    if (failLoad) throw StateError('offline');
    if (loadResult case final result?) return await result;
    return [
      for (final alert in items)
        if (!dismissed.contains(alert.id)) alert,
    ];
  }

  @override
  Future<void> markRead(String id) async {
    if (readDelay case final delay?) await delay;
    if (failMarkRead) throw StateError('failed');
    marked.add(id);
  }

  @override
  Future<void> markAllRead() async {
    if (readDelay case final delay?) await delay;
    if (failMarkRead) throw StateError('failed');
  }

  @override
  Future<void> dismiss(String id) async {
    if (dismissDelay case final delay?) await delay;
    if (failDismiss) throw StateError('failed');
    dismissed.add(id);
  }
}

void main() {
  setUp(() => _session = SessionFixture());

  test('an alert row becomes an alert with its listing and search', () {
    final alert = ListingAlertModel.fromJson(_row('a1'));

    expect(alert.type, AlertType.newListing);
    expect(alert.listing.brand, 'Yamaha');
    expect(alert.searchId, 'search-1');
    expect(alert.searchName, 'MT-07 barata');
    expect(alert.newPrice, 7400);
    expect(alert.isRead, isFalse);
  });

  test('a read alert and a deleted search are handled', () {
    final row = _row('a2', readAt: '2026-10-18T21:00:00Z')
      ..['saved_search_id'] = null
      ..['saved_searches'] = null;
    final alert = ListingAlertModel.fromJson(row);

    expect(alert.isRead, isTrue);
    expect(alert.searchId, isNull);
    expect(alert.searchName, isNull);
  });

  test('markRead updates the list at once and saves', () async {
    final repo = _FakeAlerts([
      ListingAlertModel.fromJson(_row('a1')),
      ListingAlertModel.fromJson(_row('a2')),
    ]);
    final cubit = _cubit(repo);
    await cubit.load();
    expect(cubit.state.unreadCount, 2);

    await cubit.markRead('a1');

    expect(cubit.state.unreadCount, 1);
    expect(repo.marked, ['a1']);
  });

  test('a failed save puts the alert back to unread', () async {
    final cubit = _cubit(
      _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))], failMarkRead: true),
    );
    await cubit.load();

    await cubit.markRead('a1');

    expect(cubit.state.unreadCount, 1);
  });

  test('markAllRead clears every unread alert', () async {
    final cubit = _cubit(
      _FakeAlerts([
        ListingAlertModel.fromJson(_row('a1')),
        ListingAlertModel.fromJson(_row('a2')),
      ]),
    );
    await cubit.load();

    await cubit.markAllRead();

    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.status, AlertsStatus.success);
  });

  test('read copies preserve their search and can clear the read mark', () {
    final alert = ListingAlertModel.fromJson(_row('a1'));
    final read = alert.copyWith(readAt: DateTime(2026, 10, 26));
    expect(read.searchId, alert.searchId);
    expect(read.searchName, alert.searchName);
    expect(read.isRead, isTrue);
    expect(read.copyWith(clearReadAt: true), alert);
  });

  test('refreshing a renamed search updates the alert', () async {
    final repo = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    repo.items[0] = ListingAlertModel.fromJson(
      _row('a1')..['saved_searches'] = {'name': 'A minha próxima mota'},
    );
    await cubit.load();
    expect(cubit.state.alerts.single.searchName, 'A minha próxima mota');
  });

  test('dismiss waits for persistence and stays hidden on refresh', () async {
    final saved = Completer<void>();
    final repo = _FakeAlerts([
      ListingAlertModel.fromJson(_row('a1')),
      ListingAlertModel.fromJson(_row('a2')),
    ])..dismissDelay = saved.future;
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    final dismiss = cubit.dismiss('a1');
    expect(cubit.state.alerts, hasLength(2));
    expect(cubit.state.unreadCount, 2);
    saved.complete();
    expect(await dismiss, isTrue);
    expect(cubit.state.alerts.map((alert) => alert.id), ['a2']);
    expect(cubit.state.unreadCount, 1);
    await cubit.load();
    expect(cubit.state.alerts.map((alert) => alert.id), ['a2']);
    expect(repo.items, hasLength(2));
  });

  test('a failed dismissal keeps the alert and its unread badge', () async {
    final alert = ListingAlertModel.fromJson(_row('a1'));
    final cubit = _cubit(_FakeAlerts([alert], failDismiss: true));
    addTearDown(cubit.close);
    await cubit.load();
    expect(await cubit.dismiss(alert.id), isFalse);
    expect(cubit.state.alerts, [alert]);
    expect(cubit.state.unreadCount, 1);
  });

  for (final all in [false, true]) {
    test(
      'a failed ${all ? 'markAllRead' : 'markRead'} cannot undo dismissal',
      () async {
        final write = Completer<void>();
        final repo = _FakeAlerts([
          ListingAlertModel.fromJson(_row('a1')),
          ListingAlertModel.fromJson(_row('a2')),
        ], failMarkRead: true)..readDelay = write.future;
        final cubit = _cubit(repo);
        addTearDown(cubit.close);
        await cubit.load();

        final read = all ? cubit.markAllRead() : cubit.markRead('a1');
        expect(await cubit.dismiss('a1'), isTrue);
        write.complete();
        await read;
        expect(cubit.state.alerts.map((alert) => alert.id), ['a2']);
        expect(cubit.state.unreadCount, 1);
      },
    );
  }

  test('a failed read does not undo another alert being read', () async {
    final write = Completer<void>();
    final repo = _FakeAlerts([
      ListingAlertModel.fromJson(_row('a1')),
      ListingAlertModel.fromJson(_row('a2')),
    ])..readDelay = write.future;
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    final first = cubit.markRead('a1');
    repo.readDelay = null;
    await cubit.markRead('a2');
    repo.failMarkRead = true;
    write.complete();
    await first;
    expect(cubit.state.alerts[0].isRead, isFalse);
    expect(cubit.state.alerts[1].isRead, isTrue);
  });

  test('an older refresh cannot bring a dismissed alert back', () async {
    final repo = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    final response = Completer<List<ListingAlert>>();
    repo.loadResult = response.future;
    final refresh = cubit.load();
    expect(await cubit.dismiss('a1'), isTrue);
    response.complete(List.of(repo.items));
    await refresh;
    expect(cubit.state.alerts, isEmpty);
    expect(cubit.state.unreadCount, 0);
  });

  test('an older load cannot overwrite a newer result', () async {
    final repo = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    final response = Completer<List<ListingAlert>>();
    repo.loadResult = response.future;
    final older = cubit.load();
    repo.loadResult = null;
    repo.items.add(ListingAlertModel.fromJson(_row('a2')));
    await cubit.load();
    response.complete([repo.items.first]);
    await older;
    expect(cubit.state.alerts, hasLength(2));
  });

  test(
    'a pending refresh retains new alerts while excluding a dismissal',
    () async {
      final repo = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final response = Completer<List<ListingAlert>>();
      repo.loadResult = response.future;
      final refresh = cubit.load();
      expect(await cubit.dismiss('a1'), isTrue);
      response.complete([
        repo.items.first,
        ListingAlertModel.fromJson(_row('a2')),
      ]);
      await refresh;
      expect(cubit.state.alerts.map((alert) => alert.id), ['a2']);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test('a pending refresh can finish after the cubit closes', () async {
    final response = Completer<List<ListingAlert>>();
    final repo = _FakeAlerts([])..loadResult = response.future;
    final cubit = _cubit(repo);
    final load = cubit.load();
    await cubit.close();
    response.complete([]);
    await load;
  });

  test('an account change clears alerts and the badge even offline', () async {
    final repository = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
    final cubit = _cubit(repository);
    await cubit.load();
    repository.failLoad = true;

    await _session.changeAccount('other');

    expect(cubit.state.alerts, isEmpty);
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.status, AlertsStatus.failure);
  });

  for (final fails in [false, true]) {
    test(
      'an old alert load cannot ${fails ? 'fail' : 'replace'} a new account',
      () async {
        final response = Completer<List<ListingAlert>>();
        final repository = _FakeAlerts([
          ListingAlertModel.fromJson(_row('current')),
        ])..loadResult = response.future;
        final cubit = _cubit(repository);
        final older = cubit.load();
        repository.loadResult = null;
        await _session.changeAccount('other');
        final current = cubit.state;

        if (fails) {
          response.completeError(StateError('offline'));
        } else {
          response.complete([ListingAlertModel.fromJson(_row('private'))]);
        }
        await older;

        expect(cubit.state, current);
        expect(cubit.state.alerts.single.id, 'current');
      },
    );
  }

  test('dismissal completion stays with its account', () async {
    final response = Completer<void>();
    final repository = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))])
      ..dismissDelay = response.future;
    final cubit = _cubit(repository);
    await cubit.load();
    final dismissing = cubit.dismiss('a1');
    await _session.changeAccount('other');
    final current = cubit.state;

    response.complete();

    expect(await dismissing, isFalse);
    expect(cubit.state, current);
  });

  test('dismissal guards are reset with the account scope', () async {
    final repository = _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))]);
    final cubit = _cubit(repository);
    await cubit.load();
    await cubit.dismiss('a1');
    repository.dismissed.clear();

    await _session.changeAccount('other');

    expect(cubit.state.alerts.single.id, 'a1');
  });

  test('a price reduction keeps the old and the new price', () {
    final row = _row('a3')
      ..['type'] = 'price_reduction'
      ..['old_price'] = 7600
      ..['new_price'] = 7300;
    final alert = ListingAlertModel.fromJson(row);

    expect(alert.type, AlertType.priceReduction);
    expect(alert.oldPrice, 7600);
    expect(alert.newPrice, 7300);
  });

  test('an excellent-opportunity alert is recognised', () {
    final row = _row('a4')..['type'] = 'excellent_opportunity';
    final alert = ListingAlertModel.fromJson(row);

    expect(alert.type, AlertType.excellentOpportunity);
  });

  test('a removed-listing alert is recognised', () {
    final row = _row('a5')..['type'] = 'listing_removed';
    final alert = ListingAlertModel.fromJson(row);

    expect(alert.type, AlertType.listingRemoved);
  });
}
