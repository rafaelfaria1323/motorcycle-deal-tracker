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
  String? model;
  List<({String id, List<PhotoFeatures> photos})>? features;
  List<String>? finished;

  @override
  Future<int> finishPhotoExams(List<String> ids) async {
    finished = ids;
    return ids.length;
  }

  @override
  Future<int> storePhotoFeatures(
    String model,
    List<({String id, List<PhotoFeatures> photos})> listings,
  ) async {
    this.model = model;
    features = listings;
    return listings.length;
  }

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

/// Answers in turn: a share of `fallen`, null (unreadable) or a failure.
class _Examiner implements PhotoExaminer {
  _Examiner(this.answers);

  final List<Object?> answers;
  var seen = 0;

  @override
  String get model => 'test-model';

  @override
  Future<PhotoExamination?> examine(List<int> photo) async {
    final answer = answers[seen++];
    return switch (answer) {
      final double p => (scores: {'fallen': p}, features: 'AAE='),
      final Exception e => throw e,
      _ => null,
    };
  }

  @override
  Future<void> close() async {}

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

  test("the photo CDN's robots.txt refusing stops the step and leaves "
      'the listing unchecked', () async {
    final store = _Store();
    final out = StringBuffer();
    final fetcher = _Fetcher({
      '$_cdn/a-1/image': _photo,
      '$_cdn/b-1/image': _photo,
      '$_cdn/b-2/image': const FetchDisallowed(
        'disallowed by robots.txt (Disallow: /)',
      ),
    });

    final stored = await fingerprintPhotos(
      store,
      fetcher,
      [_pending('a', 1), _pending('b', 2), _pending('c', 1)],
      examiner: _Examiner([0.1, 0.1]),
      out: out,
    );

    expect(stored, 1);
    expect([for (final l in store.stored!) l.id], ['a']);
    expect([for (final l in store.features!) l.id], ['a']);
    expect(fetcher.requested, hasLength(3));
    expect('$out', contains('Stopped: disallowed by robots.txt'));
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

  test('with an examiner the same photos are examined, by their place in '
      'the ad', () async {
    final store = _Store();
    final fetcher = _Fetcher({
      '$_cdn/a-1/image': _photo,
      '$_cdn/a-2/image': const FetchFailed('HTTP 404', statusCode: 404),
      '$_cdn/a-3/image': _photo,
      '$_cdn/b-1/image': _photo,
    });

    await fingerprintPhotos(
      store,
      fetcher,
      [_pending('a', 3), _pending('b', 1)],
      examiner: _Examiner([0.9, null, 0.2]),
      out: StringBuffer(),
    );

    // No request more than the fingerprints'.
    expect(fetcher.requested, hasLength(4));
    expect(store.model, 'test-model');
    expect([for (final l in store.features!) l.id], ['a', 'b']);
    final a = store.features!.first.photos;
    // The third photo, whose answer was null, is left out.
    expect([for (final p in a) p.photo], [0]);
    expect(a.single.examination.scores, {'fallen': 0.9});
    expect(store.features!.last.photos.single.photo, 0);
  });

  test('an examiner that fails leaves the rest fingerprinted, without '
      'hints', () async {
    final store = _Store();
    final out = StringBuffer();
    await fingerprintPhotos(
      store,
      _Fetcher({
        '$_cdn/a-1/image': _photo,
        '$_cdn/b-1/image': _photo,
        '$_cdn/b-2/image': _photo,
        '$_cdn/c-1/image': _photo,
      }),
      [_pending('a', 1), _pending('b', 2), _pending('c', 1)],
      examiner: _Examiner([0.5, const PhotoExaminerFailed('it died')]),
      out: out,
    );

    expect([for (final l in store.stored!) l.id], ['a', 'b', 'c']);
    expect([for (final l in store.stored!) l.hashes.length], [1, 2, 1]);
    // b was cut short: it waits for its hints whole.
    expect([for (final l in store.features!) l.id], ['a']);
    expect('$out', contains('Photo hints stopped: it died'));
  });

  test('without an examiner no hints are stored', () async {
    final store = _Store();
    await fingerprintPhotos(store, _Fetcher({'$_cdn/a-1/image': _photo}), [
      _pending('a', 1),
    ], out: StringBuffer());
    expect(store.features, isNull);
  });

  test('a listing asked for in full has every photo examined, only the '
      'first ones fingerprinted, then is marked done', () async {
    final store = _Store();
    final out = StringBuffer();
    final fetcher = _Fetcher({
      for (var i = 1; i <= 5; i++) '$_cdn/a-$i/image': _photo,
      for (var i = 1; i <= 3; i++) '$_cdn/b-$i/image': _photo,
    });

    await fingerprintPhotos(
      store,
      fetcher,
      [_pending('a', 5), _pending('b', 4)],
      examiner: _Examiner([0.1, 0.1, 0.1, 0.1, 0.9, 0.1, 0.1, 0.1]),
      exams: {'a'},
      out: out,
    );

    // b, not asked for, stops at its third photo.
    expect(fetcher.requested, hasLength(8));
    expect([for (final l in store.stored!) l.hashes.length], [3, 3]);
    expect(
      [for (final p in store.features!.first.photos) p.photo],
      [0, 1, 2, 3, 4],
    );
    expect(store.finished, ['a']);
    expect('$out', contains('a: 3 photo(s), 5 examined'));
  });

  test('without an examiner a listing asked for in full is only '
      'fingerprinted and keeps waiting', () async {
    final store = _Store();
    final fetcher = _Fetcher({
      for (var i = 1; i <= 3; i++) '$_cdn/a-$i/image': _photo,
    });
    await fingerprintPhotos(
      store,
      fetcher,
      [_pending('a', 5)],
      exams: {'a'},
      out: StringBuffer(),
    );

    expect(fetcher.requested, hasLength(3));
    expect(store.finished, isNull);
  });

  test(
    'a listing asked for in full and cut short is not marked done',
    () async {
      final store = _Store();
      await fingerprintPhotos(
        store,
        _Fetcher({
          for (var i = 1; i <= 3; i++) '$_cdn/a-$i/image': _photo,
          '$_cdn/a-4/image': const FetchLimitReached('5 minutes'),
        }),
        [_pending('a', 5)],
        examiner: _Examiner([0.1, 0.1, 0.1]),
        exams: {'a'},
        out: StringBuffer(),
      );

      expect(store.stored, isEmpty);
      expect(store.finished, isNull);
    },
  );
}
