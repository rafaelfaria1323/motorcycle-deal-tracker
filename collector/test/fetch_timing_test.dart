import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:collector/collector.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2030, 10, 25, 12);
final _url = Uri.parse('https://www.olx.pt${FetchSite.olx.pathPrefix}test/');
const _robots = 'User-agent: *\nAllow: /\n';

void _withFetcher(
  void Function(
    FakeAsync async,
    PoliteFetcher fetcher,
    _Client client,
    Map<String, String> files,
  )
  body, {
  FetchPolicy policy = const FetchPolicy(
    minDelay: Duration.zero,
    jitter: Duration.zero,
  ),
  FetchState? state,
}) {
  final files = <String, String>{
    if (state != null) 'state.json': jsonEncode(state.toJson()),
  };
  final client = _Client();
  fakeAsync((async) {
    IOOverrides.runZoned(
      () => HttpOverrides.runZoned(() {
        final fetcher = PoliteFetcher(
          site: const FetchSite(
            host: 'www.olx.pt',
            pathPrefix: '/carros-motos-e-barcos/motociclos-scooters/',
            pageMarker: '__PRERENDERED_STATE__',
            statePath: 'state.json',
          ),
          policy: policy,
        );
        try {
          body(async, fetcher, client, files);
          expect(async.pendingTimers, isEmpty);
        } finally {
          fetcher.close();
        }
      }, createHttpClient: (_) => client),
      createFile: (path) => _MemoryFile(path, files),
    );
  }, initialTime: _now);
}

void main() {
  test(
    'spacing starts at response end and counts intervening work exactly',
    () {
      _withFetcher((async, fetcher, client, _) {
        client.responseDelay = const Duration(seconds: 1);
        unawaited(fetcher.prepare());
        async.elapse(const Duration(seconds: 1));
        expect(client.requests, [_now]);

        unawaited(fetcher.get(_url));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5, milliseconds: 999));
        expect(client.requests, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(client.requests.last, _now.add(const Duration(seconds: 7)));
        async.elapse(const Duration(seconds: 1));

        async.elapse(const Duration(seconds: 3));
        unawaited(fetcher.get(_url));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2, milliseconds: 999));
        expect(client.requests, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(client.requests.last, _now.add(const Duration(seconds: 14)));
        async.elapse(const Duration(seconds: 1));
      }, policy: const FetchPolicy(jitter: Duration.zero));
    },
  );

  test('the default jitter always keeps requests 6 to 10 seconds apart', () {
    _withFetcher((async, fetcher, client, _) {
      unawaited(fetcher.prepare());
      async.flushMicrotasks();
      for (var i = 0; i < 4; i++) {
        unawaited(fetcher.get(_url));
        async.flushTimers();
        final gap = client.requests.last.difference(
          client.requests[client.requests.length - 2],
        );
        expect(gap, greaterThanOrEqualTo(const Duration(seconds: 6)));
        expect(gap, lessThanOrEqualTo(const Duration(seconds: 10)));
      }
    }, policy: const FetchPolicy());
  });

  test('the run deadline stops new requests, not a completed response', () {
    _withFetcher(
      (async, fetcher, client, _) {
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        String? saved;
        unawaited(
          fetcher.get(_url).then((page) {
            saved = page;
          }),
        );
        async.elapse(const Duration(milliseconds: 300));
        expect(saved, '__PRERENDERED_STATE__');
        unawaited(
          expectLater(fetcher.get(_url), throwsA(isA<FetchLimitReached>())),
        );
        async.flushMicrotasks();
        expect(client.requests, hasLength(2));
        expect(saved, '__PRERENDERED_STATE__');
      },
      policy: const FetchPolicy(
        minDelay: Duration(milliseconds: 300),
        jitter: Duration.zero,
        maxRunTime: Duration(milliseconds: 150),
      ),
    );
  });

  for (final age in [
    const Duration(hours: 24) - const Duration(milliseconds: 1),
    const Duration(hours: 24),
  ]) {
    test('robots cache boundary at $age', () {
      _withFetcher(
        (async, fetcher, client, _) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          expect(
            client.requests,
            hasLength(age < const Duration(hours: 24) ? 0 : 1),
          );
        },
        state: FetchState(
          day: '2030-10-25',
          robots: _robots,
          robotsReadAt: _now.subtract(age),
        ),
      );
    });
  }

  test('a block expires at exactly 24 hours, never a millisecond sooner', () {
    _withFetcher(
      (async, fetcher, client, files) {
        unawaited(expectLater(fetcher.prepare(), throwsA(isA<FetchRefused>())));
        async.flushMicrotasks();
        expect(client.requests, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        expect(client.requests, hasLength(1));
        final state = jsonDecode(files['state.json']!) as Map<String, dynamic>;
        expect(state['blocked_at'], isNull);
        expect(state['robots_read_at'], clock.now().toIso8601String());
      },
      state: FetchState(
        day: '2030-10-24',
        blockedAt: _now.subtract(
          const Duration(hours: 24) - const Duration(milliseconds: 1),
        ),
      ),
    );
  });

  test(
    'a new UTC day rolls request counts without discarding fresh robots',
    () {
      _withFetcher(
        (async, fetcher, client, files) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          expect(client.requests, isEmpty);
          unawaited(fetcher.get(_url));
          async.flushMicrotasks();
          final state =
              jsonDecode(files['state.json']!) as Map<String, dynamic>;
          expect(state['day'], '2030-10-25');
          expect(state['requests'], 1);
          expect(client.requests, hasLength(1));
        },
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
          maxRequestsPerDay: 10,
        ),
        state: FetchState(
          day: '2030-10-24',
          requests: 10,
          robots: _robots,
          robotsReadAt: _now.subtract(const Duration(hours: 1)),
        ),
      );
    },
  );
}

class _MemoryFile implements File {
  _MemoryFile(this.path, this.files);

  @override
  final String path;
  final Map<String, String> files;

  @override
  Future<bool> exists() async => files.containsKey(path);

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      files[path] ?? (throw FileSystemException('File not found', path));

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    files[path] = contents;
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    final contents = files.remove(path);
    if (contents == null) throw FileSystemException('File not found', path);
    files[newPath] = contents;
    return _MemoryFile(newPath, files);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  final requests = <DateTime>[];
  Duration responseDelay = Duration.zero;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(clock.now());
    return _Request(
      url.path == '/robots.txt' ? _robots : '__PRERENDERED_STATE__',
      responseDelay,
    );
  }

  @override
  set userAgent(String? value) {}

  @override
  set connectionTimeout(Duration? value) {}

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.body, this.delay);

  final String body;
  final Duration delay;

  @override
  final headers = _Headers();

  @override
  set followRedirects(bool value) {}

  @override
  Future<HttpClientResponse> close() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return _Response(body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response implements HttpClientResponse {
  _Response(this.body);

  final String body;

  @override
  int get statusCode => 200;

  @override
  final headers = _Headers();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      Stream<List<int>>.value(utf8.encode(body)).transform(streamTransformer);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  String? value(String name) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
