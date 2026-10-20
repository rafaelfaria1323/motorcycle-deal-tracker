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

void main() {
  late HttpServer server;
  late Directory dir;
  late FetchSite site;
  final requestTimes = <DateTime>[];
  final paths = <String>[];

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
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requestTimes.add(DateTime.now());
      paths.add(request.uri.toString());
      final page = int.tryParse(request.uri.queryParameters['page'] ?? '');
      request.response
        ..write(
          request.uri.path == '/robots.txt'
              ? 'User-agent: *\nAllow: /\n'
              : _page(page ?? 1, 3),
        )
        ..close();
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
