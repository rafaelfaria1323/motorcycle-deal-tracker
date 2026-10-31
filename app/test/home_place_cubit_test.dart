import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/home_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/place.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/home_place_cubit.dart';

import 'helpers/session_fixture.dart';

const _porto = Place(key: 'porto', name: 'Porto');
const _braga = Place(key: 'braga', name: 'Braga');

class _Homes implements HomeRepository {
  /// Each getHome waits for the next completer, in order.
  final reads = <Completer<Place?>>[];
  Place? saved;
  Object? saveError;

  @override
  Future<Place?> getHome() {
    final read = Completer<Place?>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<void> saveHome(Place place) async {
    if (saveError case final error?) throw error;
    saved = place;
  }

  @override
  Future<List<Place>> search(String text) async => const [];
}

HomePlaceCubit _cubit(HomeRepository homes) {
  final session = SessionFixture();
  return session.track(HomePlaceCubit(homes, session.cubit));
}

void main() {
  test('no home is known only once it was read', () async {
    final homes = _Homes();
    final cubit = _cubit(homes);
    expect(cubit.state.noHome, isFalse);

    final load = cubit.load();
    expect(cubit.state.status, HomePlaceStatus.loading);
    expect(cubit.state.noHome, isFalse);

    homes.reads.single.complete(null);
    await load;
    expect(cubit.state.status, HomePlaceStatus.success);
    expect(cubit.state.noHome, isTrue);
  });

  test('a failed read keeps the distance offered', () async {
    final homes = _Homes();
    final cubit = _cubit(homes);

    final load = cubit.load();
    homes.reads.single.completeError(StateError('offline'));
    await load;

    expect(cubit.state.status, HomePlaceStatus.failure);
    expect(cubit.state.noHome, isFalse);
  });

  test('saving sets the home, and an older read is dropped', () async {
    final homes = _Homes();
    final cubit = _cubit(homes);

    final load = cubit.load();
    await cubit.save(_porto);
    expect(homes.saved, _porto);
    expect(
      cubit.state,
      const HomePlaceState(status: HomePlaceStatus.success, home: _porto),
    );

    // The read asked before the save answers late, with the old home.
    homes.reads.single.complete(_braga);
    await load;
    expect(cubit.state.home, _porto);
  });

  test('a save that fails throws and changes nothing', () async {
    final homes = _Homes()..saveError = StateError('denied');
    final cubit = _cubit(homes);

    await expectLater(cubit.save(_porto), throwsStateError);
    expect(cubit.state, const HomePlaceState());
  });

  test('another account reads its own home', () async {
    final homes = _Homes();
    final session = SessionFixture();
    final cubit = session.track(HomePlaceCubit(homes, session.cubit));
    await cubit.save(_porto);

    await session.changeAccount('other');
    expect(cubit.state.home, isNull);
    expect(cubit.state.status, HomePlaceStatus.loading);

    homes.reads.single.complete(_braga);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.home, _braga);
  });
}
