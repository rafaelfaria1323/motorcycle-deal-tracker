import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// Sends every request to a local server instead of the real site.
class _LocalClient implements HttpClient {
  _LocalClient(this._inner, this._port);

  final HttpClient _inner;
  final int _port;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(
    url.replace(scheme: 'http', host: 'localhost', port: _port),
  );

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _page(int page, int totalPages) {
  final state = {
    'listing': {
      'listing': {
        'pageNumber': page,
        'totalPages': totalPages,
        'totalElements': 0,
        'ads': <Object>[],
        'requestParams': {'categoryPath': 'x', 'params': <String, String>{}},
      },
    },
  };
  return '<script>window.__PRERENDERED_STATE__= '
      '${jsonEncode(jsonEncode(state))};</script>';
}

/// A Standvirtual search page of a search with [total] listings.
String _standvirtualPage(int total) {
  final search = {
    'advertSearch': {
      'totalCount': total,
      'pageInfo': {'pageSize': 32, 'currentOffset': 0},
      'edges': <Object>[],
    },
  };
  final data = {
    'props': {
      'pageProps': {
        'urqlState': {
          'a': {'data': jsonEncode(search)},
        },
      },
    },
  };
  return '<script id="__NEXT_DATA__" type="application/json">'
      '${jsonEncode(data)}</script>';
}

void main() {
  late HttpServer server;
  late Directory dir;
  late FetchSite site;
  final requestTimes = <DateTime>[];
  final paths = <String>[];
  // What the server answers for a page other than robots.txt.
  late String Function(int page) answer;
  // Its status, and how long it waits before answering.
  late int Function(int page) status;
  late Duration Function(int page) delay;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('fetch');
    site = FetchSite(
      host: FetchSite.olx.host,
      pathPrefix: FetchSite.olx.pathPrefix,
      pageMarker: FetchSite.olx.pageMarker,
      statePath: '${dir.path}/state.json',
    );
    requestTimes.clear();
    paths.clear();
    answer = (page) => _page(page, 3);
    status = (_) => 200;
    delay = (_) => Duration.zero;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestTimes.add(DateTime.now());
      paths.add(request.uri.toString());
      final page = int.tryParse(request.uri.queryParameters['page'] ?? '');
      final robots = request.uri.path == '/robots.txt';
      if (!robots) {
        await Future<void>.delayed(delay(page ?? 1));
        request.response.statusCode = status(page ?? 1);
      }
      request.response.write(
        robots ? 'User-agent: *\nAllow: /\n' : answer(page ?? 1),
      );
      try {
        await request.response.close();
      } on Object catch (_) {
        // The fetcher gave up waiting (the timeout test).
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Future<T> local<T>(Future<T> Function() body) {
    final inner = HttpClient();
    return HttpOverrides.runZoned(
      body,
      createHttpClient: (_) => _LocalClient(inner, server.port),
    );
  }

  final search = Uri.parse(
    'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/'
    '?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07',
  );

  test('saves every page of a search and the manifest', () async {
    final outcome = await local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );
      await fetcher.prepare();
      try {
        return await fetchSearches(
          fetcher,
          [search],
          dir.path,
          out: StringBuffer(),
        );
      } finally {
        fetcher.close();
      }
    });

    expect(outcome.saved, 3);
    expect(outcome.stoppedBy, isNull);
    final manifest = (await SearchManifest.readFrom(dir.path))!;
    expect(manifest.planned, ['$search']);
    expect(manifest.files.values.toSet(), {'$search'});
    expect(paths.where((p) => p.contains('page=')), hasLength(2));
  });

  test(
    'a Standvirtual search over 32 listings has its pages fetched',
    () async {
      answer = (_) => _standvirtualPage(40);
      final standvirtual = FetchSite(
        host: FetchSite.standvirtual.host,
        pathPrefix: FetchSite.standvirtual.pathPrefix,
        pageMarker: FetchSite.standvirtual.pageMarker,
        statePath: '${dir.path}/state.json',
      );
      final mt07 = Uri.parse('https://www.standvirtual.com/motos/yamaha/mt-07');
      final outcome = await local(() async {
        final fetcher = PoliteFetcher(
          site: standvirtual,
          policy: const FetchPolicy(
            minDelay: Duration.zero,
            jitter: Duration.zero,
          ),
        );
        await fetcher.prepare();
        try {
          return await fetchSearches(
            fetcher,
            [mt07],
            dir.path,
            out: StringBuffer(),
          );
        } finally {
          fetcher.close();
        }
      });

      expect(outcome.saved, 2);
      expect(paths.last, '/motos/yamaha/mt-07?page=2');
      expect((await SearchManifest.readFrom(dir.path))!.files.values.toSet(), {
        '$mt07',
      });
    },
  );

  test('the request budget running out keeps what was saved', () async {
    final outcome = await local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
          maxRequestsPerRun: 3, // robots.txt + 2 of the 3 pages
        ),
      );
      await fetcher.prepare();
      try {
        return await fetchSearches(
          fetcher,
          [search],
          dir.path,
          out: StringBuffer(),
        );
      } finally {
        fetcher.close();
      }
    });

    expect(outcome.saved, 2);
    expect(outcome.stoppedBy, contains('run limit'));
    expect((await SearchManifest.readFrom(dir.path))!.files, hasLength(2));
  });

  Future<FetchOutcome> fetchWith(FetchPolicy policy) => local(() async {
    final fetcher = PoliteFetcher(site: site, policy: policy);
    await fetcher.prepare();
    try {
      return await fetchSearches(
        fetcher,
        [search],
        dir.path,
        out: StringBuffer(),
      );
    } finally {
      fetcher.close();
    }
  });

  test('a request that times out keeps what was saved, as a failure', () async {
    delay = (page) => page == 3 ? const Duration(seconds: 2) : Duration.zero;

    final outcome = await fetchWith(
      const FetchPolicy(
        minDelay: Duration.zero,
        jitter: Duration.zero,
        timeout: Duration(milliseconds: 300),
      ),
    );

    expect(outcome.saved, 2);
    expect(outcome.failure, isA<FetchFailed>());
    expect(outcome.stoppedBy, contains('timed out'));
    // Page 3 is missing, so the search is not read in full: nothing of it
    // is removed.
    expect((await SearchManifest.readFrom(dir.path))!.files, hasLength(2));
  });

  test('a block after a page keeps that page, as a failure', () async {
    status = (page) => page == 2 ? 503 : 200;

    final outcome = await fetchWith(
      const FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero),
    );

    expect(outcome.saved, 1);
    expect(outcome.failure, isA<FetchBlocked>());
  });

  test('a failure before any page throws', () async {
    status = (_) => 503;

    await expectLater(
      fetchWith(
        const FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero),
      ),
      throwsA(isA<FetchBlocked>()),
    );
  });

  test('an OLX search with an engine band and no ads is not saved', () async {
    answer = (page) => _page(page, 1); // no ads
    final banded = search.replace(
      queryParameters: {
        ...search.queryParameters,
        olxEngineSize: '501-1000-cc',
      },
    );
    final log = StringBuffer();

    final outcome = await local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );
      await fetcher.prepare();
      try {
        return await fetchSearches(
          fetcher,
          [banded, search],
          dir.path,
          out: log,
        );
      } finally {
        fetcher.close();
      }
    });

    // The plain search's empty page is saved (no band: it can be empty).
    expect(outcome.saved, 1);
    final manifest = (await SearchManifest.readFrom(dir.path))!;
    expect(manifest.planned, ['$banded', '$search']);
    expect(manifest.files.values, ['$search']);
    expect('$log', contains('OLX found no ads'));
  });

  test('the pause between requests counts the time spent in between', () async {
    // Wide margins: a loaded CI machine can be slow by a few hundred ms.
    const pause = Duration(milliseconds: 1000);
    await local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(minDelay: pause, jitter: Duration.zero),
      );
      await fetcher.prepare(); // robots.txt
      final page = search.replace(path: '${search.path}x');
      await fetcher.get(page); // waits the whole pause
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final before = DateTime.now();
      await fetcher.get(page); // only the rest of the pause is left
      final waited = DateTime.now().difference(before);
      fetcher.close();

      // About 300 ms are left; without counting the time in between it
      // would be the whole 1000 ms.
      expect(waited, lessThan(const Duration(milliseconds: 800)));
    });

    for (var i = 1; i < requestTimes.length; i++) {
      expect(
        requestTimes[i].difference(requestTimes[i - 1]),
        greaterThanOrEqualTo(pause - const Duration(milliseconds: 20)),
      );
    }
  });
}
