import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_alert_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/alerts_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/alerts_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/alerts_state.dart';

Map<String, dynamic> _row(String id, {String? readAt}) => {
  'id': id,
  'type': 'new_listing',
  'new_price': 7400,
  'old_price': null,
  'read_at': readAt,
  'created_at': '2026-10-18T20:00:00Z',
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
  _FakeAlerts(this.items, {this.failMarkRead = false});

  final List<ListingAlert> items;
  final bool failMarkRead;
  final marked = <String>[];

  @override
  Future<List<ListingAlert>> getAll() async => items;

  @override
  Future<void> markRead(String id) async {
    if (failMarkRead) throw StateError('failed');
    marked.add(id);
  }

  @override
  Future<void> markAllRead() async {
    if (failMarkRead) throw StateError('failed');
  }
}

void main() {
  test('an alert row becomes an alert with its listing and search', () {
    final alert = ListingAlertModel.fromJson(_row('a1'));

    expect(alert.type, AlertType.newListing);
    expect(alert.listing.brand, 'Yamaha');
    expect(alert.searchName, 'MT-07 barata');
    expect(alert.newPrice, 7400);
    expect(alert.isRead, isFalse);
  });

  test('a read alert and a deleted search are handled', () {
    final row = _row('a2', readAt: '2026-10-18T21:00:00Z')
      ..['saved_searches'] = null;
    final alert = ListingAlertModel.fromJson(row);

    expect(alert.isRead, isTrue);
    expect(alert.searchName, isNull);
  });

  test('markRead updates the list at once and saves', () async {
    final repo = _FakeAlerts([
      ListingAlertModel.fromJson(_row('a1')),
      ListingAlertModel.fromJson(_row('a2')),
    ]);
    final cubit = AlertsCubit(repo);
    await cubit.load();
    expect(cubit.state.unreadCount, 2);

    await cubit.markRead('a1');

    expect(cubit.state.unreadCount, 1);
    expect(repo.marked, ['a1']);
  });

  test('a failed save puts the alert back to unread', () async {
    final cubit = AlertsCubit(
      _FakeAlerts([ListingAlertModel.fromJson(_row('a1'))], failMarkRead: true),
    );
    await cubit.load();

    await cubit.markRead('a1');

    expect(cubit.state.unreadCount, 1);
  });

  test('markAllRead clears every unread alert', () async {
    final cubit = AlertsCubit(
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
}
