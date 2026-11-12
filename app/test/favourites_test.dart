import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/favourites/data/models/favourite_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/repositories/favourites_repository.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/cubit/favourites_cubit.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/cubit/favourites_state.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/favourites_text.dart';

import 'helpers/session_fixture.dart';

late SessionFixture _session;

FavouritesCubit _cubit(
  FavouritesRepository repository, {
  DateTime Function()? clock,
}) => _session.track(FavouritesCubit(repository, _session.cubit, clock: clock));

Map<String, dynamic> _listingRow(String id, {String status = 'active'}) => {
  'id': id,
  'source': 'olx',
  'url': 'https://example.com/$id',
  'brand': 'Yamaha',
  'model': 'MT-07',
  'price': 6500,
  'seller_type': 'private',
  'status': status,
  'images': <String>[],
  'first_seen_at': '2026-10-10T10:00:00Z',
  'last_seen_at': '2026-10-18T10:00:00Z',
};

Listing _listing(String id, {String status = 'active'}) =>
    ListingModel.fromJson(_listingRow(id, status: status));

final _added = DateTime(2026, 10, 15, 12);

Favourite _favourite(String id, {String? note, String status = 'active'}) =>
    Favourite(
      listingId: id,
      createdAt: _added,
      note: note,
      listing: _listing(id, status: status),
    );

/// Saving l1's note waits for [l1Save]; the rest save at once.
class _SlowNotes extends _FakeFavourites {
  _SlowNotes(super.items);

  final l1Save = Completer<void>();

  @override
  Future<void> saveNote(String listingId, String? note) =>
      listingId == 'l1' ? l1Save.future : super.saveNote(listingId, note);
}

/// Loads work until [down].
class _GoesDown extends _FakeFavourites {
  _GoesDown(super.items);

  var down = false;

  @override
  Future<List<Favourite>> getAll() =>
      down ? Future.error(StateError('offline')) : super.getAll();
}

class _DeferredFavourites extends _FakeFavourites {
  _DeferredFavourites(super.items);

  Future<List<Favourite>>? loadResult;

  /// Completes once a load is asking (after the unsent checklists, N.66).
  final loadAsked = Completer<void>();

  @override
  Future<List<Favourite>> getAll() async {
    if (!loadAsked.isCompleted) loadAsked.complete();
    return await (loadResult ?? super.getAll());
  }
}

class _FakeFavourites implements FavouritesRepository {
  _FakeFavourites(this.items, {this.fail = false, this.failWrites = false});

  final List<Favourite> items;
  final bool fail;

  /// Loads work, saving fails.
  final bool failWrites;

  /// No connection (N.66): checklists fail to save, though not refused;
  /// loads fail too.
  var offline = false;

  /// This device's copies.
  List<Favourite>? copy;
  final unsent = <String, Map<String, ChecklistEntry>>{};
  final calls = <String>[];
  Future<void>? writeDelay;

  @override
  Future<List<Favourite>?> lastCopy() async => copy;

  @override
  Future<Map<String, Map<String, ChecklistEntry>>> unsentChecklists() async =>
      Map.of(unsent);

  @override
  Future<void> keepUnsentChecklist(
    String listingId,
    Map<String, ChecklistEntry>? checklist,
  ) async {
    if (checklist == null) {
      unsent.remove(listingId);
    } else {
      unsent[listingId] = checklist;
    }
  }

  @override
  Future<List<Favourite>> getAll() async {
    if (fail) throw StateError('offline');
    if (offline) throw Exception('no connection');
    return List.of(items);
  }

  @override
  Future<void> add(String listingId) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    calls.add('add $listingId');
  }

  @override
  Future<void> remove(String listingId) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    calls.add('remove $listingId');
  }

  @override
  Future<void> saveNote(String listingId, String? note) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    calls.add('note $listingId $note');
  }

  @override
  Future<void> saveTargetPrice(String listingId, double? targetPrice) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    calls.add('target $listingId $targetPrice');
  }

  @override
  Future<void> saveVisit(String listingId, DateTime? visitAt) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    calls.add('visit $listingId ${visitAt?.toUtc().toIso8601String()}');
  }

  @override
  Future<void> saveChecklist(
    String listingId,
    Map<String, ChecklistEntry> checklist,
  ) async {
    if (writeDelay case final delay?) await delay;
    if (fail || failWrites) throw StateError('offline');
    if (offline) throw Exception('no connection');
    if (!items.any((f) => f.listingId == listingId)) {
      throw StateError('not a favourite');
    }
    calls.add('checklist $listingId ${checklist.keys.join(',')}');
  }
}

void main() {
  setUp(() => _session = SessionFixture());

  test('a favourite row becomes a favourite with its listing and note', () {
    final favourite = FavouriteModel.fromJson({
      'listing_id': 'l1',
      'note': 'Liguei, ainda disponível',
      'created_at': '2026-10-15T12:00:00Z',
      'listings': _listingRow('l1'),
    });

    expect(favourite.listingId, 'l1');
    expect(favourite.note, 'Liguei, ainda disponível');
    expect(favourite.createdAt, DateTime.utc(2026, 10, 15, 12).toLocal());
    expect(favourite.listing?.model, 'MT-07');
    expect(favourite.targetPrice, isNull);
    expect(
      FavouriteModel.fromJson({
        'listing_id': 'l1',
        'target_price': 6800,
        'created_at': '2026-10-15T12:00:00Z',
      }).targetPrice,
      6800,
    );
    expect(favourite.visitAt, isNull);
    expect(
      FavouriteModel.fromJson({
        'listing_id': 'l1',
        'visit_at': '2026-11-13T10:00:00+00:00',
        'created_at': '2026-10-15T12:00:00Z',
      }).visitAt,
      DateTime.utc(2026, 11, 13, 10).toLocal(),
    );
    expect(FavouriteModel.columns, contains('visit_at'));
  });

  test('the checklist is read leniently and written back the same', () {
    final checklist = FavouriteModel.checklistFromJson({
      'tyres': {'mark': 'issue', 'note': 'DOT 2017'},
      'documents': {'mark': 'ok'},
      'chain': {'note': 'Folga a mais'},
      'keys': {'mark': 'maybe'},
      'brakes': 'ok',
    });
    expect(checklist, {
      'tyres': const ChecklistEntry(
        mark: ChecklistMark.issue,
        note: 'DOT 2017',
      ),
      'documents': const ChecklistEntry(mark: ChecklistMark.ok),
      'chain': const ChecklistEntry(note: 'Folga a mais'),
    });
    expect(FavouriteModel.checklistToJson(checklist), {
      'tyres': {'mark': 'issue', 'note': 'DOT 2017'},
      'documents': {'mark': 'ok'},
      'chain': {'note': 'Folga a mais'},
    });
    expect(FavouriteModel.checklistFromJson(null), isEmpty);
    expect(FavouriteModel.checklistFromJson(['tyres']), isEmpty);
  });

  test('the checklists waiting on this device are read back the same', () {
    final unsent = {
      'l1': {
        'tyres': const ChecklistEntry(mark: ChecklistMark.issue, note: 'DOT'),
      },
      'l2': <String, ChecklistEntry>{},
    };
    expect(
      FavouriteModel.unsentFromJson(FavouriteModel.unsentToJson(unsent)),
      unsent,
    );
    expect(FavouriteModel.unsentFromJson(null), isEmpty);
    expect(FavouriteModel.unsentFromJson('{broken'), isEmpty);
    expect(FavouriteModel.unsentFromJson('[1]'), isEmpty);
  });

  test('a row without its listing or note is handled', () {
    final favourite = FavouriteModel.fromJson({
      'listing_id': 'l1',
      'note': null,
      'created_at': '2026-10-15T12:00:00Z',
      'listings': null,
    });

    expect(favourite.note, isNull);
    expect(favourite.checklist, isEmpty);
    expect(favourite.listing, isNull);
  });

  group('FavouritesCubit', () {
    test('load shows the favourites; a failed refresh keeps them', () async {
      final repo = _FakeFavourites([_favourite('l1')]);
      final cubit = _cubit(repo);
      await cubit.load();
      expect(cubit.state.status, FavouritesStatus.success);
      expect(cubit.state.isFavourite('l1'), isTrue);
      expect(cubit.state.isFavourite('l2'), isFalse);

      final failing = _cubit(_FakeFavourites([], fail: true));
      await failing.load();
      expect(failing.state.status, FavouritesStatus.failure);
    });

    test(
      'toggle adds a listing first in the list, then takes it out',
      () async {
        final repo = _FakeFavourites([_favourite('l1')]);
        final now = DateTime(2026, 10, 20, 9);
        final cubit = _cubit(repo, clock: () => now);
        await cubit.load();

        expect(await cubit.toggle(_listing('l2')), isTrue);
        expect(cubit.state.favourites.map((f) => f.listingId), ['l2', 'l1']);
        expect(cubit.state.favouriteOf('l2')?.createdAt, now);
        expect(cubit.state.favouriteOf('l2')?.listing?.id, 'l2');

        expect(await cubit.toggle(_listing('l1')), isTrue);
        expect(cubit.state.favourites.map((f) => f.listingId), ['l2']);
        expect(repo.calls, ['add l2', 'remove l1']);
      },
    );

    test('a toggle that fails to save is undone', () async {
      final cubit = _cubit(_FakeFavourites([], fail: true));

      expect(await cubit.toggle(_listing('l1')), isFalse);
      expect(cubit.state.isFavourite('l1'), isFalse);
    });

    test('saveNote trims, clears an empty note and leaves others', () async {
      final repo = _FakeFavourites([
        _favourite('l1', note: 'Antiga'),
        _favourite('l2', note: 'Outra'),
      ]);
      final cubit = _cubit(repo);
      await cubit.load();

      expect(await cubit.saveNote('l1', '  Pede 6 500 €  '), isTrue);
      expect(cubit.state.favouriteOf('l1')?.note, 'Pede 6 500 €');
      expect(await cubit.saveNote('l1', '   '), isTrue);
      expect(cubit.state.favouriteOf('l1')?.note, isNull);
      expect(cubit.state.favouriteOf('l2')?.note, 'Outra');
      expect(repo.calls, ['note l1 Pede 6 500 €', 'note l1 null']);
    });

    test('a note on a listing that is not a favourite is not saved', () async {
      final repo = _FakeFavourites([]);
      final cubit = _cubit(repo);
      await cubit.load();

      expect(await cubit.saveNote('l9', 'x'), isFalse);
      expect(repo.calls, isEmpty);
    });

    test('a checklist item is marked, noted and cleared', () async {
      final repo = _FakeFavourites([_favourite('l1', note: 'Antiga')]);
      final cubit = _cubit(repo);
      await cubit.load();

      expect(
        await cubit.saveChecklistItem('l1', 'tyres', mark: ChecklistMark.issue),
        ChecklistSave.saved,
      );
      expect(
        await cubit.saveChecklistItem(
          'l1',
          'chain',
          mark: ChecklistMark.ok,
          note: '  Nova  ',
        ),
        ChecklistSave.saved,
      );
      expect(cubit.state.favouriteOf('l1')?.checklist, {
        'tyres': const ChecklistEntry(mark: ChecklistMark.issue),
        'chain': const ChecklistEntry(mark: ChecklistMark.ok, note: 'Nova'),
      });
      expect(cubit.state.favouriteOf('l1')?.note, 'Antiga');

      // No mark and a blank note: the item is gone.
      expect(
        await cubit.saveChecklistItem('l1', 'tyres', note: ' '),
        ChecklistSave.saved,
      );
      expect(cubit.state.favouriteOf('l1')?.checklist.keys, ['chain']);
      expect(repo.calls, [
        'checklist l1 tyres',
        'checklist l1 tyres,chain',
        'checklist l1 chain',
      ]);

      expect(
        await cubit.saveChecklistItem('l9', 'tyres'),
        ChecklistSave.failed,
      );
    });

    test('a checklist item that fails to save is undone', () async {
      final cubit = _cubit(
        _FakeFavourites([_favourite('l1')], failWrites: true),
      );
      await cubit.load();

      expect(
        await cubit.saveChecklistItem('l1', 'tyres', mark: ChecklistMark.ok),
        ChecklistSave.failed,
      );
      expect(cubit.state.favouriteOf('l1')?.checklist, isEmpty);
    });

    test('without a connection a checklist mark stays and waits', () async {
      final repo = _FakeFavourites([_favourite('l1'), _favourite('l2')]);
      final cubit = _cubit(repo);
      await cubit.load();
      repo.offline = true;

      expect(
        await cubit.saveChecklistItem('l1', 'tyres', mark: ChecklistMark.ok),
        ChecklistSave.kept,
      );
      expect(cubit.state.favouriteOf('l1')?.checklist, {
        'tyres': const ChecklistEntry(mark: ChecklistMark.ok),
      });
      expect(cubit.state.unsent, {'l1'});
      expect(repo.unsent.keys, ['l1']);

      // Still offline: a refresh keeps the list and the mark.
      await cubit.load();
      expect(cubit.state.unsent, {'l1'});
      expect(cubit.state.favouriteOf('l1')?.checklist.keys, ['tyres']);
      expect(repo.calls, isEmpty);

      // Back online: a save elsewhere sends it too.
      repo.offline = false;
      expect(
        await cubit.saveChecklistItem('l2', 'chain', mark: ChecklistMark.ok),
        ChecklistSave.saved,
      );
      await pumpEventQueue();
      expect(repo.calls, ['checklist l2 chain', 'checklist l1 tyres']);
      expect(repo.unsent, isEmpty);
      expect(cubit.state.unsent, isEmpty);
    });

    test('a load sends what waited before reading the list', () async {
      final repo = _FakeFavourites([_favourite('l1')])
        ..unsent['l1'] = {
          'tyres': const ChecklistEntry(mark: ChecklistMark.issue),
        };
      final cubit = _cubit(repo);
      await cubit.load();

      expect(repo.calls, ['checklist l1 tyres']);
      expect(repo.unsent, isEmpty);
      expect(cubit.state.unsent, isEmpty);
    });

    test(
      'a waiting checklist for a favourite gone meanwhile is dropped',
      () async {
        final repo = _FakeFavourites([_favourite('l1')])
          ..unsent['l9'] = {
            'tyres': const ChecklistEntry(mark: ChecklistMark.ok),
          };
        final cubit = _cubit(repo);
        await cubit.load();

        expect(repo.calls, isEmpty);
        expect(repo.unsent, isEmpty);
      },
    );

    test(
      'without a connection the device copy is shown with its marks',
      () async {
        final repo = _FakeFavourites([])
          ..offline = true
          ..copy = [_favourite('l1', note: 'Ligar antes')]
          ..unsent['l1'] = {
            'tyres': const ChecklistEntry(mark: ChecklistMark.ok),
          };
        final cubit = _cubit(repo);
        await cubit.load();

        expect(cubit.state.status, FavouritesStatus.success);
        expect(cubit.state.fromDevice, isTrue);
        expect(cubit.state.unsent, {'l1'});
        expect(cubit.state.favouriteOf('l1')?.note, 'Ligar antes');
        expect(cubit.state.favouriteOf('l1')?.checklist.keys, ['tyres']);

        // The connection is back: the database's list, the mark sent.
        repo
          ..offline = false
          ..items.add(_favourite('l1', note: 'Ligar antes'));
        await cubit.load();
        expect(cubit.state.fromDevice, isFalse);
        expect(cubit.state.unsent, isEmpty);
        expect(repo.calls, ['checklist l1 tyres']);
      },
    );

    test('without a connection or a copy loading fails', () async {
      final cubit = _cubit(_FakeFavourites([])..offline = true);
      await cubit.load();
      expect(cubit.state.status, FavouritesStatus.failure);
    });

    test('a target price is set, cleared, and undone when it fails', () async {
      final repo = _FakeFavourites([_favourite('l1')]);
      final cubit = _cubit(repo);
      await cubit.load();

      expect(await cubit.saveTargetPrice('l1', 6800), isTrue);
      expect(cubit.state.favouriteOf('l1')?.targetPrice, 6800);
      expect(cubit.state.favouriteOf('l1')?.withNote('x').targetPrice, 6800);
      expect(await cubit.saveTargetPrice('l1', null), isTrue);
      expect(cubit.state.favouriteOf('l1')?.targetPrice, isNull);
      expect(await cubit.saveTargetPrice('l9', 1), isFalse);
      expect(repo.calls, ['target l1 6800.0', 'target l1 null']);

      final failing = _cubit(
        _FakeFavourites([_favourite('l1')], failWrites: true),
      );
      await failing.load();
      expect(await failing.saveTargetPrice('l1', 6800), isFalse);
      expect(failing.state.favouriteOf('l1')?.targetPrice, isNull);
    });

    test(
      'a visit is planned, moved, cleared, and undone when it fails',
      () async {
        final repo = _FakeFavourites([_favourite('l1')]);
        final cubit = _cubit(repo);
        await cubit.load();
        final at = DateTime.utc(2026, 11, 13, 10);

        expect(await cubit.saveVisit('l1', at), isTrue);
        expect(cubit.state.favouriteOf('l1')?.visitAt, at);
        // The other edits keep it.
        expect(cubit.state.favouriteOf('l1')?.withNote('x').visitAt, at);
        expect(cubit.state.favouriteOf('l1')?.withTargetPrice(1).visitAt, at);
        expect(cubit.state.favouriteOf('l1')?.withChecklist({}).visitAt, at);
        expect(await cubit.saveVisit('l1', null), isTrue);
        expect(cubit.state.favouriteOf('l1')?.visitAt, isNull);
        expect(await cubit.saveVisit('l9', at), isFalse);
        expect(repo.calls, [
          'visit l1 2026-11-13T10:00:00.000Z',
          'visit l1 null',
        ]);

        final failing = _cubit(
          _FakeFavourites([_favourite('l1')], failWrites: true),
        );
        await failing.load();
        expect(await failing.saveVisit('l1', at), isFalse);
        expect(failing.state.favouriteOf('l1')?.visitAt, isNull);
      },
    );

    test('a note that fails to save is undone', () async {
      final cubit = _cubit(
        _FakeFavourites([_favourite('l1', note: 'Antiga')], failWrites: true),
      );
      await cubit.load();

      expect(await cubit.saveNote('l1', 'Nova'), isFalse);
      expect(cubit.state.favouriteOf('l1')?.note, 'Antiga');
    });

    test('undoing a failed save keeps a later change to another', () async {
      final repo = _SlowNotes([_favourite('l1'), _favourite('l2')]);
      final cubit = _cubit(repo);
      await cubit.load();

      final first = cubit.saveNote('l1', 'Primeira');
      expect(await cubit.saveNote('l2', 'Segunda'), isTrue);
      repo.l1Save.completeError(StateError('offline'));

      expect(await first, isFalse);
      expect(cubit.state.favouriteOf('l1')?.note, isNull);
      expect(cubit.state.favouriteOf('l2')?.note, 'Segunda');
    });

    test("another account's favourites go even if loading fails", () async {
      final repo = _GoesDown([_favourite('l1', note: 'Privada')]);
      final cubit = _cubit(repo);
      await cubit.load();
      repo.down = true;

      await cubit.load(); // a refresh that fails keeps them
      expect(cubit.state.isFavourite('l1'), isTrue);
      await _session.changeAccount('other');
      expect(cubit.state.favourites, isEmpty);
      expect(cubit.state.status, FavouritesStatus.failure);
    });

    test(
      "an old load cannot restore another account's private notes",
      () async {
        final response = Completer<List<Favourite>>();
        final repo = _DeferredFavourites([_favourite('l2', note: 'Current')])
          ..loadResult = response.future;
        final cubit = _cubit(repo);
        addTearDown(cubit.close);
        final older = cubit.load();
        repo.loadResult = null;
        await _session.changeAccount('other');

        response.complete([_favourite('l1', note: 'Private')]);
        await older;

        expect(cubit.state.favourites.map((f) => f.listingId), ['l2']);
      },
    );

    test("a failed old save cannot restore another account's note", () async {
      final repo = _SlowNotes([_favourite('l1', note: 'Private')]);
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final saving = cubit.saveNote('l1', 'Changed');
      repo.items[0] = _favourite('l1', note: 'Current');
      await _session.changeAccount('other');

      repo.l1Save.completeError(StateError('offline'));
      expect(await saving, isFalse);

      expect(cubit.state.favouriteOf('l1')?.note, 'Current');
    });

    test('a newer refresh wins within the same account', () async {
      final response = Completer<List<Favourite>>();
      final repo = _DeferredFavourites([_favourite('current')])
        ..loadResult = response.future;
      final cubit = _cubit(repo);
      final older = cubit.load();
      repo.loadResult = null;
      await cubit.load();

      response.complete([_favourite('old')]);
      await older;

      expect(cubit.state.favourites.map((f) => f.listingId), ['current']);
    });

    final changes = <String, Future<bool> Function(FavouritesCubit)>{
      'add': (cubit) => cubit.toggle(_listing('l2')),
      'remove': (cubit) => cubit.toggle(_listing('l1')),
      'note': (cubit) => cubit.saveNote('l1', 'Changed'),
      'target': (cubit) => cubit.saveTargetPrice('l1', 6000),
      'checklist': (cubit) => cubit
          .saveChecklistItem('l1', 'tyres', mark: ChecklistMark.issue)
          .then((saved) => saved == ChecklistSave.saved),
    };
    for (final change in changes.entries) {
      for (final fails in [false, true]) {
        test(
          '${change.key} ${fails ? 'failure' : 'success'} stays in its account',
          () async {
            final response = Completer<void>();
            final repo = _FakeFavourites([_favourite('l1', note: 'Private')])
              ..writeDelay = response.future;
            final cubit = _cubit(repo);
            await cubit.load();
            final saving = change.value(cubit);
            repo.items[0] = _favourite('l1', note: 'Current');
            await _session.changeAccount('other');
            final current = cubit.state;

            if (fails) {
              response.completeError(StateError('offline'));
            } else {
              response.complete();
            }

            expect(await saving, isFalse);
            expect(cubit.state, current);
          },
        );
      }
    }

    for (final fails in [false, true]) {
      test('a load can ${fails ? 'fail' : 'finish'} after closing', () async {
        final response = Completer<List<Favourite>>();
        final repo = _DeferredFavourites([])..loadResult = response.future;
        final cubit = _cubit(repo);
        final loading = cubit.load();
        await repo.loadAsked.future;
        await cubit.close();

        if (fails) {
          response.completeError(StateError('offline'));
        } else {
          response.complete([_favourite('old')]);
        }
        await loading;

        expect(cubit.state.favourites, isEmpty);
      });
    }
  });

  test('normalizeNote trims and keeps notes within the limit', () {
    expect(normalizeNote(' a '), 'a');
    expect(normalizeNote('\n '), isNull);
    final long = 'x' * (FavouritesCubit.maxNoteLength + 10);
    expect(normalizeNote(long)!.length, FavouritesCubit.maxNoteLength);
    expect(normalizeNote('abc d', 4), 'abc');
  });

  test('favouriteSinceText says when it was added', () {
    final now = DateTime(2026, 10, 18, 12);
    expect(
      favouriteSinceText(_favourite('l1'), now: now),
      'Adicionado aos favoritos há 3 dias',
    );
    expect(
      favouriteSinceText(_favourite('l1'), now: _added),
      'Adicionado aos favoritos hoje',
    );
  });

  test('visitText: today, tomorrow, later, gone by', () {
    final now = DateTime(2026, 11, 12, 9);
    expect(
      visitText(DateTime(2026, 11, 12, 18, 30), now: now),
      'Visita hoje às 18:30',
    );
    expect(
      visitText(DateTime(2026, 11, 13, 10), now: now),
      'Visita amanhã às 10:00',
    );
    expect(
      visitText(DateTime(2026, 11, 20, 9, 5), now: now),
      'Visita a 20/11/2026 às 09:05',
    );
    expect(
      visitText(DateTime(2026, 11, 12, 8), now: now),
      'Visita a 12/11/2026 (já passou)',
    );
    expect(
      visitText(
        DateTime(2026, 11, 13, 10),
        now: now,
        language: AppLanguage.english,
      ),
      'Viewing tomorrow at 10:00',
    );
  });

  test('favouritesCountText counts the listings and the removed ones', () {
    expect(favouritesCountText([_favourite('a')]), '1 anúncio');
    expect(
      favouritesCountText([
        _favourite('a'),
        _favourite('b', status: 'removed'),
      ]),
      '2 anúncios, 1 já removido',
    );
    expect(
      favouritesCountText([
        _favourite('a', status: 'removed'),
        _favourite('b', status: 'removed'),
        _favourite('c'),
      ]),
      '3 anúncios, 2 já removidos',
    );
  });
}
