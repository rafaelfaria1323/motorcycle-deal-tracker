import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// Sends every request to a local socket instead of the real host.
class _ToLocal implements HttpClient {
  _ToLocal(this._inner, this._port);

  final HttpClient _inner;
  final int _port;

  Uri _local(Uri url) =>
      url.replace(scheme: 'http', host: 'localhost', port: _port);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(_local(url));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(_local(url));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ServerSocket server;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('dropped');
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      socket.listen((bytes) {
        final robots = utf8.decode(bytes).startsWith('GET /robots.txt');
        // robots.txt is answered in full; anything else is cut off after
        // a few of the promised bytes, as a dropped connection is.
        const robotsTxt = 'User-agent: *\nAllow: /\n';
        socket.write(
          robots
              ? 'HTTP/1.1 200 OK\r\nContent-Length: ${robotsTxt.length}\r\n'
                    'Connection: close\r\n\r\n$robotsTxt'
              : 'HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\nabc',
        );
        socket.close();
      });
    });
  });

  tearDown(() async {
    await server.close();
    dir.deleteSync(recursive: true);
  });

  Future<T> local<T>(Future<T> Function() body) {
    // Made outside the zone: inside it, HttpClient() would be the override.
    final inner = HttpClient();
    return HttpOverrides.runZoned(
      body,
      createHttpClient: (_) => _ToLocal(inner, server.port),
    );
  }

  test('a connection dropped mid-page is a failed fetch, not a crash', () {
    final site = FetchSite(
      host: FetchSite.standvirtual.host,
      pathPrefix: FetchSite.standvirtual.pathPrefix,
      pageMarker: FetchSite.standvirtual.pageMarker,
      statePath: '${dir.path}/state.json',
    );
    return local(() async {
      final fetcher = PoliteFetcher(
        site: site,
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );
      await fetcher.prepare();
      try {
        await expectLater(
          fetcher.get(Uri.parse('https://www.standvirtual.com/motos/yamaha')),
          throwsA(isA<FetchFailed>()),
        );
      } finally {
        fetcher.close();
      }
    });
  });

  test('a dropped Telegram connection fails the send without the token', () {
    return local(() async {
      final notifier = TelegramNotifier(token: 'SECRET', chatId: '1');
      final error = await notifier
          .send('x')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<NotifyFailed>());
      expect(error.toString(), isNot(contains('SECRET')));
    });
  });
}
