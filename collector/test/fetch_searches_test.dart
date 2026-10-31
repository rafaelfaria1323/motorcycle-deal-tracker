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

/// An OLX search page; [ads] are (published, top ad) pairs.
String _page(
  int page,
  int totalPages, {
  List<(DateTime, bool)> ads = const [],
}) {
  final state = {
    'listing': {
      'listing': {
        'pageNumber': page,
        'totalPages': totalPages,
        'totalElements': ads.length,
        'ads': [
          for (final (i, (published, top)) in ads.indexed)
            {
              'id': page * 100 + i,
              'title': 'Yamaha MT-07',
              'url': 'https://www.olx.pt/d/anuncio/x-ID${page * 100 + i}.html',
              'status': 'active',
              'description': 'Mota',
              'isBusiness': false,
              'isPromoted': top,
              'createdTime': published.toIso8601String(),
              'lastRefreshTime': null,
              'params': <Object>[],
              'price': {
                'regularPrice': {'value': 7000, 'currencyCode': 'EUR'},
              },
            },
        ],
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
  final paths = <String>[];
  // What the server answers for a page other than robots.txt.
  late String Function(int page) answer;
  // Its status, and how long it waits before answering.
  late int Function(int page) status;
  late Duration Function(int page) delay;
  late String robotsTxt;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('fetch');
    site = FetchSite(
      host: FetchSite.olx.host,
      pathPrefix: FetchSite.olx.pathPrefix,
      pageMarker: FetchSite.olx.pageMarker,
      statePath: '${dir.path}/state.json',
    );
    paths.clear();
    answer = (page) => _page(page, 3);
    status = (_) => 200;
    delay = (_) => Duration.zero;
    robotsTxt = 'User-agent: *\nAllow: /\n';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.toString());
      final page = int.tryParse(request.uri.queryParameters['page'] ?? '');
      final robots = request.uri.path == '/robots.txt';
      if (!robots) {
        await Future<void>.delayed(delay(page ?? 1));
        request.response.statusCode = status(page ?? 1);
      }
      request.response.write(robots ? robotsTxt : answer(page ?? 1));
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
    expect(manifest.pages, {'$search': 3});
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
    final r7 = search.replace(
      queryParameters: {'search[filter_enum_modelo][0]': 'r7'},
    );
    final log = StringBuffer();
    final outcome = await local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
          // robots.txt, the first search's 3 pages and 1 of the second's.
          maxRequestsPerRun: 5,
        ),
      );
      await fetcher.prepare();
      try {
        return await fetchSearches(fetcher, [search, r7], dir.path, out: log);
      } finally {
        fetcher.close();
      }
    });

    expect(outcome.saved, 4);
    expect(outcome.stoppedBy, contains('run limit'));
    expect('$log', contains('. 1 of 2 search(es) not read in full'));
    final manifest = (await SearchManifest.readFrom(dir.path))!;
    expect(manifest.files, hasLength(4));
    // The second search still spans 3: the run read 1 of them.
    expect(manifest.pages, {'$search': 3, '$r7': 3});
  });

  Future<FetchOutcome> fetchWith(FetchPolicy policy, {StringSink? out}) =>
      local(() async {
        final fetcher = PoliteFetcher(site: site, policy: policy);
        await fetcher.prepare();
        try {
          return await fetchSearches(
            fetcher,
            [search],
            dir.path,
            out: out ?? StringBuffer(),
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
        // Retried once, and it times out again.
        retryDelay: Duration(milliseconds: 10),
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

    final log = StringBuffer();
    final outcome = await fetchWith(
      const FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero),
      out: log,
    );

    expect(outcome.saved, 1);
    expect(outcome.failure, isA<FetchBlocked>());
    expect(
      '$log',
      contains(
        '. 1 of 1 search(es) not read in full this run; '
        'the 1 page(s) saved are imported.',
      ),
    );
  });

  test('a page our rules refuse keeps what was saved, as a failure', () async {
    robotsTxt = 'User-agent: *\nDisallow: /*page=2\n';

    final outcome = await fetchWith(
      const FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero),
    );

    expect(outcome.saved, 1);
    expect(outcome.failure, isA<FetchRefused>());
    expect((await SearchManifest.readFrom(dir.path))!.files, hasLength(1));
  });

  test('a damaged state file starts afresh', () async {
    File(site.statePath).writeAsStringSync('{"day": "2026-');

    await local(() async {
      final fetcher = PoliteFetcher(site: site);
      try {
        await fetcher.prepare();
      } finally {
        fetcher.close();
      }
    });
    expect(paths, ['/robots.txt']);
    // Written back whole, counting only this run's request.
    final state = (await readFetchState(site.statePath))!;
    expect(state.requests, 1);
    expect(state.blockedAt, isNull);
  });

  group('robots.txt kept for 24 hours', () {
    const policy = FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero);

    Future<int> prepare() => local(() async {
      final fetcher = PoliteFetcher(site: site, policy: policy);
      try {
        await fetcher.prepare();
        return fetcher.requestsThisRun;
      } finally {
        fetcher.close();
      }
    });

    void keep(String text, Duration age) =>
        File(site.statePath).writeAsStringSync(
          jsonEncode(
            FetchState(
              day: '2026-10-19',
              robots: text,
              robotsReadAt: DateTime.now().toUtc().subtract(age),
            ).toJson(),
          ),
        );

    test('the next run uses the one read by the run before', () async {
      expect(await prepare(), 1);
      expect(await prepare(), 0);
      expect(paths, ['/robots.txt']);
      expect((await readFetchState(site.statePath))!.robots, robotsTxt);
    });

    test('the one kept still decides what may be read', () async {
      keep('User-agent: *\nDisallow: /*page=2\n', const Duration(hours: 1));

      final outcome = await fetchWith(policy);

      expect(outcome.saved, 1);
      expect(outcome.failure, isA<FetchRefused>());
      expect(paths.where((p) => p == '/robots.txt'), isEmpty);
    });

    test('one 24 hours old is read again and replaced', () async {
      keep('User-agent: *\nDisallow: /\n', const Duration(hours: 24));

      expect(await prepare(), 1);
      expect(paths, ['/robots.txt']);
      final state = (await readFetchState(site.statePath))!;
      expect(state.robots, robotsTxt);
      expect(
        DateTime.now().toUtc().difference(state.robotsReadAt!),
        lessThan(const Duration(minutes: 1)),
      );
    });

    test('a block forgets it, so the run after the pause reads it', () async {
      status = (_) => 503;

      await expectLater(fetchWith(policy), throwsA(isA<FetchBlocked>()));

      final state = (await readFetchState(site.statePath))!;
      expect(state.blockedAt, isNotNull);
      expect(state.robots, isNull);
      expect(state.robotsReadAt, isNull);
    });
  });

  test('no request cap unless one is set', () async {
    final outcome = await fetchWith(
      const FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero),
    );

    expect(outcome.saved, 3);
    expect(outcome.stoppedBy, isNull);
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

  group('light runs (R.2)', () {
    const policy = FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero);
    final now = DateTime.now().toUtc();

    Future<FetchOutcome> lightRun({StringSink? out}) => local(() async {
      final fetcher = PoliteFetcher(site: site, policy: policy);
      await fetcher.prepare();
      try {
        return await fetchSearches(
          fetcher,
          [search],
          dir.path,
          light: true,
          out: out ?? StringBuffer(),
        );
      } finally {
        fetcher.close();
      }
    });

    void readInFull(Duration ago) => File(site.statePath).writeAsStringSync(
      jsonEncode(
        FetchState(
          day: '2026-10-19',
          robots: robotsTxt,
          robotsReadAt: now,
          fullReads: {'$search': now.subtract(ago)},
        ).toJson(),
      ),
    );

    test('a search read in full lately stops at older ads', () async {
      readInFull(const Duration(hours: 4));
      // Page 2 reaches back past the full read (less the margin).
      answer = (page) => _page(
        page,
        3,
        ads: [
          (now, false),
          if (page == 2) (now.subtract(const Duration(hours: 7)), false),
        ],
      );
      final log = StringBuffer();

      final outcome = await lightRun(out: log);

      expect(outcome.saved, 2);
      expect(paths.first, contains('search%5Border%5D=created_at%3Adesc'));
      expect(paths.where((p) => p.contains('page=3')), isEmpty);
      final manifest = (await SearchManifest.readFrom(dir.path))!;
      expect(manifest.newestOnly, {'$search'});
      expect(manifest.pages, {'$search': 3});
      // Not a full read: the one kept stays.
      final state = (await readFetchState(site.statePath))!;
      expect(
        state.fullReads['$search'],
        now.subtract(const Duration(hours: 4)),
      );
      expect('$log', contains('newest first: read 2 of 3 page(s)'));
    });

    test('old top ads do not stop it', () async {
      readInFull(const Duration(hours: 4));
      answer = (page) => _page(
        page,
        3,
        ads: [(now.subtract(const Duration(days: 300)), true), (now, false)],
      );

      final outcome = await lightRun();

      expect(outcome.saved, 3);
      // Every page was read: a full read after all.
      expect((await SearchManifest.readFrom(dir.path))!.newestOnly, isEmpty);
    });

    test('a search not read in full lately is read in full', () async {
      readInFull(lightRunWindow + const Duration(minutes: 1));
      answer = (page) => _page(
        page,
        3,
        ads: [(now.subtract(const Duration(days: 30)), false)],
      );
      final log = StringBuffer();

      final outcome = await lightRun(out: log);

      expect(outcome.saved, 3);
      expect(paths.where((p) => p.contains('search%5Border')), isEmpty);
      expect((await SearchManifest.readFrom(dir.path))!.newestOnly, isEmpty);
      final read = (await readFetchState(site.statePath))!.fullReads['$search'];
      expect(
        DateTime.now().toUtc().difference(read!),
        lessThan(const Duration(minutes: 1)),
      );
      expect('$log', contains('read in full'));
    });
  });

  group('lightRunCutoff', () {
    final now = DateTime.utc(2026, 10, 28, 12);

    test('none, too old or in the future: read in full', () {
      expect(lightRunCutoff(null, now), isNull);
      expect(
        lightRunCutoff(
          now.subtract(const Duration(hours: 12, seconds: 1)),
          now,
        ),
        isNull,
      );
      expect(lightRunCutoff(now.add(const Duration(minutes: 1)), now), isNull);
    });

    test('within the window: the full read less the margin', () {
      expect(
        lightRunCutoff(DateTime.utc(2026, 10, 28, 8), now),
        DateTime.utc(2026, 10, 28, 6),
      );
      expect(lightRunCutoff(now.subtract(lightRunWindow), now), isNotNull);
    });
  });

  test('the fetch state keeps the full reads', () {
    final at = DateTime.utc(2026, 10, 28, 8);
    final state = FetchState.fromJson(
      jsonDecode(
        jsonEncode(
          FetchState(day: '2026-10-28', fullReads: {'a': at}).toJson(),
        ),
      ) as Map<String, dynamic>,
    );
    expect(state.fullReads, {'a': at});
    expect(state.rolledTo('2026-10-29').fullReads, {'a': at});
    // A state file from before light runs.
    expect(
      FetchState.fromJson({'day': '2026-10-28', 'requests': 0}).fullReads,
      isEmpty,
    );
  });
}
