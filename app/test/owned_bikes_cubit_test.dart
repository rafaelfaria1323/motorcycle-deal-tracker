import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/owned_bike.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/repositories/owned_bikes_repository.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/cubit/owned_bikes_cubit.dart';

import 'helpers/session_fixture.dart';

final _draft = OwnedBikeDraft(
  motorcycleId: 'mt07',
  listingId: 'ad1',
  year: 2021,
  boughtOn: DateTime(2026, 11, 12),
  pricePaid: 5600,
);

class _Bikes implements OwnedBikesRepository {
  final stored = <OwnedBike>[];
  var lists = 0;
  Object? writeError;

  @override
  Future<List<OwnedBike>> list() async {
    lists++;
    return List.of(stored);
  }

  @override
  Future<void> add(OwnedBikeDraft bike) async {
    if (writeError case final error?) throw error;
    stored.add(
      OwnedBike(
        id: 'b${stored.length}',
        purchase: bike,
        brand: 'Yamaha',
        model: 'MT-07',
      ),
    );
  }

  @override
  Future<void> update(String id, OwnedBikeDraft bike) async {
    if (writeError case final error?) throw error;
  }

  @override
  Future<void> delete(String id) async {
    if (writeError case final error?) throw error;
    stored.removeWhere((b) => b.id == id);
  }
}

void main() {
  test('an anonymous session has no bikes and asks for none', () async {
    final session = SessionFixture(accountId: null);
    final bikes = _Bikes();
    final cubit = session.track(OwnedBikesCubit(bikes, session.cubit));

    await cubit.load();

    expect(cubit.state.status, OwnedBikesStatus.success);
    expect(cubit.state.bikes, isEmpty);
    expect(bikes.lists, 0);
  });

  test('a purchase is kept, then read again with its model', () async {
    final session = SessionFixture();
    final bikes = _Bikes();
    final cubit = session.track(OwnedBikesCubit(bikes, session.cubit));

    expect(await cubit.add(_draft), isTrue);

    expect(cubit.state.status, OwnedBikesStatus.success);
    expect(cubit.state.boughtFrom('ad1')?.name, 'Yamaha MT-07');
    expect(cubit.state.boughtFrom('ad2'), isNull);

    expect(await cubit.remove('b0'), isTrue);
    expect(cubit.state.bikes, isEmpty);
  });

  test('a failed write says so and keeps the list', () async {
    final session = SessionFixture();
    final bikes = _Bikes()..writeError = StateError('offline');
    final cubit = session.track(OwnedBikesCubit(bikes, session.cubit));

    expect(await cubit.add(_draft), isFalse);
    expect(await cubit.edit('b0', _draft), isFalse);
    expect(await cubit.remove('b0'), isFalse);
    expect(bikes.lists, 0);
  });

  test('a read that fails shows the failure', () async {
    final session = SessionFixture();
    final cubit = session.track(OwnedBikesCubit(_Failing(), session.cubit));

    await cubit.load();

    expect(cubit.state.status, OwnedBikesStatus.failure);
  });

  test('another account starts empty', () async {
    final session = SessionFixture();
    final bikes = _Bikes();
    final cubit = session.track(OwnedBikesCubit(bikes, session.cubit));
    await cubit.add(_draft);
    expect(cubit.state.bikes, hasLength(1));

    bikes.stored.clear();
    await session.changeAccount('other');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.bikes, isEmpty);
  });
}

class _Failing extends _Bikes {
  @override
  Future<List<OwnedBike>> list() async => throw StateError('offline');
}
