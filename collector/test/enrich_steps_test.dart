import 'dart:convert';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// A listing page with just enough for `parseDetails`.
String _page(String id) =>
    '<html><script id="__NEXT_DATA__" type="application/json">'
    '${jsonEncode({
      'props': {
        'pageProps': {
          'advert': {'id': id, 'description': 'Mota muito cuidada.'},
        },
      },
    })}</script></html>';

/// Answers each address with a page, or throws what it was given.
class _Fetcher implements PoliteFetcher {
  _Fetcher(this.answers);

  final Map<String, Object> answers;
  final requested = <String>[];

  @override
  Future<String> get(Uri url) async {
    requested.add('$url');
    return switch (answers['$url']) {
      final String html => html,
      final Exception e => throw e,
      _ => throw StateError('unexpected $url'),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements ListingStore {
  List<String>? storedIds;
  List<String>? failedIds;

  @override
  Future<int> applyDetails(String source, List<ListingDetails> details) async {
    // The stored id carries a site prefix ("standvirtual.com/1").
    storedIds = [for (final d in details) d.sourceListingId.split('/').last];
    return details.length;
  }

  @override
  Future<int> markDetailsFailed(String source, List<String> ids) async {
    failedIds = [for (final id in ids) id.split('/').last];
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _base = 'https://www.standvirtual.com/motos/anuncio';

({String sourceListingId, String url}) _pending(String id) =>
    (sourceListingId: StandvirtualMapper.listingId(id), url: '$_base/$id.html');

void main() {
  test('a page that is gone, unreadable or refused is skipped', () async {
    final store = _Store();
    final updated = await enrichDetails(
      store,
      _Fetcher({
        '$_base/1.html': _page('1'),
        '$_base/2.html': const FetchFailed('HTTP 404', statusCode: 404),
        '$_base/3.html': '<html>no data</html>',
        // Redirected off /motos/: our own rules refuse it.
        '$_base/4.html': const FetchRefused('only /motos/ pages'),
        '$_base/5.html': _page('5'),
        // Redirected to another ad.
        '$_base/6.html': _page('7'),
        '$_base/7.html': const FetchFailed('HTTP 410', statusCode: 410),
      }),
      [
        _pending('1'),
        _pending('2'),
        _pending('3'),
        _pending('4'),
        _pending('5'),
        _pending('6'),
        _pending('7'),
      ],
      out: StringBuffer(),
    );

    expect(updated, 2);
    expect(store.storedIds, ['1', '5']);
    // Marked, so the next runs read the listings never tried first.
    expect(store.failedIds, ['2', '3', '4', '6', '7']);
  });

  test('running out of requests stores what was read, quietly', () async {
    final store = _Store();
    final updated = await enrichDetails(
      store,
      _Fetcher({
        '$_base/1.html': _page('1'),
        '$_base/2.html': const FetchLimitReached('20 requests this run'),
      }),
      [_pending('1'), _pending('2'), _pending('3')],
      out: StringBuffer(),
    );

    expect(updated, 1);
    expect(store.storedIds, ['1']);
    // Not tried: nothing to mark.
    expect(store.failedIds, isEmpty);
  });

  for (final failure in [
    const FetchFailed('Timed out receiving the page'),
    const FetchFailed('HTTP 401', statusCode: 401),
    const FetchFailed('HTTP 500', statusCode: 500),
  ]) {
    test('a failure ($failure) stores partial details then stops', () async {
      final store = _Store();
      final fetcher = _Fetcher({
        '$_base/1.html': _page('1'),
        '$_base/2.html': failure,
        '$_base/3.html': _page('3'),
      });

      await expectLater(
        enrichDetails(store, fetcher, [
          _pending('1'),
          _pending('2'),
          _pending('3'),
        ], out: StringBuffer()),
        throwsA(same(failure)),
      );
      expect(store.storedIds, ['1']);
      expect(store.failedIds, ['2']);
      expect(fetcher.requested, ['$_base/1.html', '$_base/2.html']);
    });
  }

  test('a block stores what was read, then is rethrown', () async {
    final store = _Store();

    await expectLater(
      enrichDetails(
        store,
        _Fetcher({
          '$_base/1.html': _page('1'),
          '$_base/2.html': const FetchBlocked('HTTP 429'),
        }),
        [_pending('1'), _pending('2'), _pending('3')],
        out: StringBuffer(),
      ),
      throwsA(isA<FetchBlocked>()),
    );
    expect(store.storedIds, ['1']);
  });
}
