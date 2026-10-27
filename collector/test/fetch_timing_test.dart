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

/// No pauses and no retry: the transport tests see each request alone.
const _noRetry = FetchPolicy(
  minDelay: Duration.zero,
  jitter: Duration.zero,
  retryDelay: null,
);

/// No pauses, the default retry.
const _retry = FetchPolicy(minDelay: Duration.zero, jitter: Duration.zero);
const _retryDelay = Duration(seconds: 60);

void _withFetcher(
  void Function(
    FakeAsync async,
    PoliteFetcher fetcher,
    _Client client,
    Map<String, String> files,
  )
  body, {
  FetchPolicy policy = _noRetry,
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

  for (final status in [403, 429, 503]) {
    for (final unreadable in [false, true]) {
      test('HTTP $status persists a block without waiting for '
          '${unreadable ? 'an unreadable' : 'a stalled'} body', () {
        _withFetcher((async, fetcher, client, files) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          var cancelled = false;
          final body = StreamController<List<int>>(
            onCancel: () async {
              await Future<void>.delayed(const Duration(milliseconds: 1));
              cancelled = true;
            },
          );
          if (unreadable) {
            body.addError(const HttpException('body truncated'));
          }
          client
            ..statusCode = status
            ..body = body.stream;
          Object? failure;
          unawaited(
            fetcher
                .get(_url)
                .then<void>((_) {}, onError: (Object error) => failure = error),
          );
          async.flushMicrotasks();
          try {
            final state = FetchState.fromJson(
              jsonDecode(files['state.json']!) as Map<String, dynamic>,
            );
            expect(state.blockedAt, _now);
            expect(state.robots, isNull);
            expect(state.robotsReadAt, isNull);
            expect(
              state.report(fetcher.policy, _now)['paused_until'],
              _now.add(const Duration(hours: 24)).toIso8601String(),
            );
            expect(failure, isNull);
            async.elapse(const Duration(milliseconds: 1));
            expect(failure, isA<FetchBlocked>());
            expect(cancelled, isTrue);
            unawaited(
              expectLater(fetcher.prepare(), throwsA(isA<FetchRefused>())),
            );
            async.flushMicrotasks();
            expect(client.requests, hasLength(2));
          } finally {
            unawaited(body.close());
            async.flushMicrotasks();
          }
        });
      });
    }
  }

  test('the total body deadline cancels a response before the next get', () {
    _withFetcher((async, fetcher, client, _) {
      unawaited(fetcher.prepare());
      async.flushMicrotasks();
      var cancelling = false;
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () async {
          cancelling = true;
          await Future<void>.delayed(const Duration(seconds: 1));
          cancelled = true;
        },
      );
      client.body = body.stream;
      Object? failure;
      unawaited(
        fetcher
            .get(_url)
            .then<void>((_) {}, onError: (Object error) => failure = error),
      );
      async.elapse(const Duration(seconds: 30));
      body.add(utf8.encode('partial'));
      async.elapse(const Duration(seconds: 29));
      body.add(utf8.encode('still arriving'));
      async.elapse(const Duration(milliseconds: 999));
      expect(failure, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(cancelling, isTrue);
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 1));
      try {
        expect(
          failure,
          isA<FetchFailed>().having((e) => e.statusCode, 'statusCode', isNull),
        );
        expect(failure.toString(), '$_url: timed out');
        expect(cancelled, isTrue);
        expect(body.hasListener, isFalse);
        client.body = null;
        unawaited(fetcher.get(_url));
        async.flushMicrotasks();
        expect(client.requests, hasLength(3));
      } finally {
        unawaited(body.close());
        async.flushMicrotasks();
      }
    });
  });

  test('a header timeout aborts its request before the next get', () {
    _withFetcher((async, fetcher, client, _) {
      unawaited(fetcher.prepare());
      async.flushMicrotasks();
      final timeout = const FetchPolicy().timeout;
      client.responseDelay = timeout + const Duration(seconds: 10);
      Object? failure;
      unawaited(
        fetcher
            .get(_url)
            .then<void>((_) {}, onError: (Object error) => failure = error),
      );
      async.elapse(timeout - const Duration(milliseconds: 1));
      expect(failure, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(
        failure,
        isA<FetchFailed>().having((e) => e.statusCode, 'statusCode', isNull),
      );
      expect(client.opened.last.aborted, isTrue);
      client.responseDelay = Duration.zero;
      unawaited(fetcher.get(_url));
      async.flushMicrotasks();
      expect(client.requests, hasLength(3));
      async.elapse(const Duration(seconds: 10));
    });
  });

  for (final status in [404, 410, 500]) {
    test('HTTP $status keeps its status without reading its stalled body', () {
      _withFetcher((async, fetcher, client, _) {
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () async {
            cancelled = true;
          },
        );
        client
          ..statusCode = status
          ..body = body.stream;
        Object? failure;
        unawaited(
          fetcher
              .get(_url)
              .then<void>((_) {}, onError: (Object error) => failure = error),
        );
        async.flushMicrotasks();
        try {
          expect(
            failure,
            isA<FetchFailed>().having(
              (e) => e.statusCode,
              'statusCode',
              status,
            ),
          );
          expect(failure.toString(), '$_url: HTTP $status');
          expect(cancelled, isTrue);
          expect(body.hasListener, isFalse);
        } finally {
          unawaited(body.close());
          async.flushMicrotasks();
        }
      });
    });
  }

  group('one retry', () {
    test('a timeout is retried once, 60 s later, and counted', () {
      _withFetcher((async, fetcher, client, files) {
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        final timeout = fetcher.policy.timeout;
        client.responseDelay = timeout + const Duration(seconds: 10);
        String? page;
        Object? failure;
        unawaited(
          fetcher
              .get(_url)
              .then((p) => page = p, onError: (Object e) => failure = e),
        );
        async.elapse(timeout);
        expect(client.requests, hasLength(2));
        client.responseDelay = Duration.zero;
        async.elapse(const Duration(seconds: 59, milliseconds: 999));
        expect(client.requests, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(client.requests, hasLength(3));
        expect(client.requests.last, _now.add(timeout + _retryDelay));
        expect(page, '__PRERENDERED_STATE__');
        expect(failure, isNull);
        expect(fetcher.requestsThisRun, 3);
        final state = jsonDecode(files['state.json']!) as Map<String, dynamic>;
        expect(state['requests'], 3);
        async.elapse(const Duration(seconds: 10));
      }, policy: _retry);
    });

    for (final status in [500, 502, 504]) {
      test('HTTP $status twice fails with its status after 2 requests', () {
        _withFetcher((async, fetcher, client, _) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          client.statusCode = status;
          Object? failure;
          unawaited(
            fetcher
                .get(_url)
                .then<void>((_) {}, onError: (Object e) => failure = e),
          );
          async.elapse(_retryDelay);
          expect(
            failure,
            isA<FetchFailed>().having((e) => e.statusCode, 'status', status),
          );
          expect(client.requests, hasLength(3));
        }, policy: _retry);
      });
    }

    test('a 502 followed by the page returns the page', () {
      _withFetcher((async, fetcher, client, _) {
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        client.statuses.add(502);
        String? page;
        unawaited(fetcher.get(_url).then((p) => page = p));
        async.elapse(_retryDelay);
        expect(page, '__PRERENDERED_STATE__');
        expect(client.requests, hasLength(3));
      }, policy: _retry);
    });

    for (final status in [403, 404, 410, 429, 503]) {
      test('HTTP $status is never retried', () {
        _withFetcher((async, fetcher, client, _) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          client.statusCode = status;
          Object? failure;
          unawaited(
            fetcher
                .get(_url)
                .then<void>((_) {}, onError: (Object e) => failure = e),
          );
          async.flushMicrotasks();
          expect(failure, isNotNull);
          expect(client.requests, hasLength(2));
          async.elapse(_retryDelay * 2);
          expect(client.requests, hasLength(2));
        }, policy: _retry);
      });
    }

    test('a page that is not normal is never retried', () {
      _withFetcher((async, fetcher, client, _) {
        unawaited(fetcher.prepare());
        async.flushMicrotasks();
        client.body = Stream.value(utf8.encode('<html>verify</html>'));
        Object? failure;
        unawaited(
          fetcher
              .get(_url)
              .then<void>((_) {}, onError: (Object e) => failure = e),
        );
        async.flushMicrotasks();
        expect(failure, isA<FetchBlocked>());
        async.elapse(_retryDelay * 2);
        expect(client.requests, hasLength(2));
      }, policy: _retry);
    });

    test('the run time ending before the retry keeps the first failure', () {
      _withFetcher(
        (async, fetcher, client, _) {
          unawaited(fetcher.prepare());
          async.flushMicrotasks();
          client.statusCode = 502;
          Object? failure;
          unawaited(
            fetcher
                .get(_url)
                .then<void>((_) {}, onError: (Object e) => failure = e),
          );
          async.elapse(_retryDelay);
          expect(
            failure,
            isA<FetchFailed>().having((e) => e.statusCode, 'status', 502),
          );
          expect(client.requests, hasLength(2));
        },
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
          maxRunTime: Duration(seconds: 30),
        ),
      );
    });
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
  final opened = <_Request>[];
  Duration responseDelay = Duration.zero;
  int statusCode = 200;

  /// Statuses for the next pages, before [statusCode].
  final statuses = <int>[];
  Stream<List<int>>? body;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(clock.now());
    final robots = url.path == '/robots.txt';
    final request = _Request(
      _Response(
        robots ? _robots : '__PRERENDERED_STATE__',
        statusCode: robots
            ? 200
            : (statuses.isNotEmpty ? statuses.removeAt(0) : statusCode),
        stream: robots ? null : body,
      ),
      responseDelay,
    );
    opened.add(request);
    return request;
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
  _Request(this.response, this.delay);

  final _Response response;
  final Duration delay;
  bool aborted = false;

  @override
  final headers = _Headers();

  @override
  set followRedirects(bool value) {}

  @override
  Future<HttpClientResponse> close() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (aborted) throw const HttpException('request aborted');
    return response;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body, {this.statusCode = 200, Stream<List<int>>? stream})
    : _stream = stream;

  @override
  final int statusCode;
  final String body;
  final Stream<List<int>>? _stream;

  @override
  final headers = _Headers();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => (_stream ?? _page()).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// The page, from a stream whose cancel completes in the fake zone (a
  /// plain stream's cancel returns a root-zone future fake time never
  /// completes).
  Stream<List<int>> _page() {
    final controller = StreamController<List<int>>(onCancel: () async {});
    controller
      ..add(utf8.encode(body))
      ..close();
    return controller.stream;
  }

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
