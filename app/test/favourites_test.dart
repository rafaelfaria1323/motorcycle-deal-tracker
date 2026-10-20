import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/favourite_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/favourites_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/favourites_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/favourites_state.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/favourites_text.dart';

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

class _FakeFavourites implements FavouritesRepository {
  _FakeFavourites(this.items, {this.fail = false, this.failWrites = false});

  final List<Favourite> items;
  final bool fail;

  /// Loads work, saving fails.
  final bool failWrites;
  final calls = <String>[];

  @override
  Future<List<Favourite>> getAll() async {
    if (fail) throw StateError('offline');
    return items;
  }

  @override
  Future<void> add(String listingId) async {
    if (fail || failWrites) throw StateError('offline');
    calls.add('add $listingId');
  }

  @override
  Future<void> remove(String listingId) async {
    if (fail || failWrites) throw StateError('offline');
    calls.add('remove $listingId');
  }

  @override
  Future<void> saveNote(String listingId, String? note) async {
    if (fail || failWrites) throw StateError('offline');
    calls.add('note $listingId $note');
  }
}

void main() {
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
  });

  test('a row without its listing or note is handled', () {
    final favourite = FavouriteModel.fromJson({
      'listing_id': 'l1',
      'note': null,
      'created_at': '2026-10-15T12:00:00Z',
      'listings': null,
    });

    expect(favourite.note, isNull);
    expect(favourite.listing, isNull);
  });

  group('FavouritesCubit', () {
    test('load shows the favourites; a failed refresh keeps them', () async {
      final repo = _FakeFavourites([_favourite('l1')]);
      final cubit = FavouritesCubit(repo);
      await cubit.load();
      expect(cubit.state.status, FavouritesStatus.success);
      expect(cubit.state.isFavourite('l1'), isTrue);
      expect(cubit.state.isFavourite('l2'), isFalse);

      final failing = FavouritesCubit(_FakeFavourites([], fail: true));
      await failing.load();
      expect(failing.state.status, FavouritesStatus.failure);
    });

    test(
      'toggle adds a listing first in the list, then takes it out',
      () async {
        final repo = _FakeFavourites([_favourite('l1')]);
        final now = DateTime(2026, 10, 20, 9);
        final cubit = FavouritesCubit(repo, clock: () => now);
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
      final cubit = FavouritesCubit(_FakeFavourites([], fail: true));

      expect(await cubit.toggle(_listing('l1')), isFalse);
      expect(cubit.state.isFavourite('l1'), isFalse);
    });

    test('saveNote trims, clears an empty note and leaves others', () async {
      final repo = _FakeFavourites([
        _favourite('l1', note: 'Antiga'),
        _favourite('l2', note: 'Outra'),
      ]);
      final cubit = FavouritesCubit(repo);
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
      final cubit = FavouritesCubit(repo);
      await cubit.load();

      expect(await cubit.saveNote('l9', 'x'), isFalse);
      expect(repo.calls, isEmpty);
    });

    test('a note that fails to save is undone', () async {
      final cubit = FavouritesCubit(
        _FakeFavourites([_favourite('l1', note: 'Antiga')], failWrites: true),
      );
      await cubit.load();

      expect(await cubit.saveNote('l1', 'Nova'), isFalse);
      expect(cubit.state.favouriteOf('l1')?.note, 'Antiga');
    });
  });

  test('normalizeNote trims and keeps notes within the limit', () {
    expect(normalizeNote(' a '), 'a');
    expect(normalizeNote('\n '), isNull);
    final long = 'x' * (FavouritesCubit.maxNoteLength + 10);
    expect(normalizeNote(long)!.length, FavouritesCubit.maxNoteLength);
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
