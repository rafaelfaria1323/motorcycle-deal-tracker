import 'package:collector/collector.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

final _photo = img.encodeJpg(
  img.Image(width: 40, height: 30)..setPixelRgb(3, 3, 255, 255, 255),
);

/// Answers each address with bytes, or throws what it was given.
class _Fetcher implements PoliteFetcher {
  _Fetcher(this.answers);

  final Map<String, Object> answers;
  final requested = <String>[];

  @override
  Future<List<int>> getImage(Uri url) async {
    requested.add('$url');
    return switch (answers['$url']) {
      final List<int> bytes => bytes,
      final Exception e => throw e,
      _ => throw StateError('unexpected $url'),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements ListingStore {
  List<({String id, List<int> hashes})>? stored;

  @override
  Future<int> storePhotoHashes(
    List<({String id, List<int> hashes})> listings,
  ) async {
    stored = listings;
    return listings.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _cdn = 'https://ireland.apollo.olxcdn.com/v1/files';

({String id, List<String> images}) _pending(String id, int photos) =>
    (id: id, images: [for (var i = 1; i <= photos; i++) '$_cdn/$id-$i/image']);

void main() {
  test('the first three photos; gone, refused or unreadable ones are left '
      'out', () async {
    final store = _Store();
    final fetcher = _Fetcher({
      '$_cdn/a-1/image': _photo,
      '$_cdn/a-2/image': const FetchFailed('HTTP 404', statusCode: 404),
      '$_cdn/a-3/image': [1, 2, 3],
      '$_cdn/b-1/image': const FetchRefused('not the photo CDN'),
    });

    final stored = await fingerprintPhotos(store, fetcher, [
      _pending('a', 5),
      _pending('b', 1),
    ], out: StringBuffer());

    expect(stored, 2);
    expect(fetcher.requested, [
      '$_cdn/a-1/image',
      '$_cdn/a-2/image',
      '$_cdn/a-3/image',
      '$_cdn/b-1/image',
    ]);
    expect(store.stored!.first.hashes, [photoHash(_photo)]);
    // Done even with no photo, so it is not asked for again.
    expect(store.stored!.last.id, 'b');
    expect(store.stored!.last.hashes, isEmpty);
  });

  test('running out of time keeps the listings done, quietly', () async {
    final store = _Store();
    final stored = await fingerprintPhotos(
      store,
      _Fetcher({
        '$_cdn/a-1/image': _photo,
        '$_cdn/b-1/image': _photo,
        '$_cdn/b-2/image': const FetchLimitReached('5 minutes'),
      }),
      [_pending('a', 1), _pending('b', 2), _pending('c', 1)],
      out: StringBuffer(),
    );

    expect(stored, 1);
    // b was cut short: it waits for the next run whole.
    expect([for (final l in store.stored!) l.id], ['a']);
  });

  for (final failure in [
    const FetchBlocked('HTTP 429'),
    const FetchFailed('Timed out receiving the page'),
    const FetchFailed('HTTP 500', statusCode: 500),
  ]) {
    test('a failure ($failure) stores what was read, then stops', () async {
      final store = _Store();
      final fetcher = _Fetcher({
        '$_cdn/a-1/image': _photo,
        '$_cdn/b-1/image': failure,
      });

      await expectLater(
        fingerprintPhotos(store, fetcher, [
          _pending('a', 1),
          _pending('b', 1),
          _pending('c', 1),
        ], out: StringBuffer()),
        throwsA(same(failure)),
      );
      expect([for (final l in store.stored!) l.id], ['a']);
      expect(fetcher.requested, ['$_cdn/a-1/image', '$_cdn/b-1/image']);
    });
  }
}
