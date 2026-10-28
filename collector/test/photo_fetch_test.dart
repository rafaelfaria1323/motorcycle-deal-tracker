import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// Sends every request to the local server instead of the real host.
class _ToLocal implements HttpClient {
  _ToLocal(this._inner, this._port);

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

void main() {
  late HttpServer server;
  late Directory dir;
  late int robotsStatus;
  late String robotsTxt;
  final accepts = <String?>[];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('photos');
    robotsStatus = 404;
    robotsTxt = 'User-agent: *\nDisallow: /';
    accepts.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      accepts.add(request.headers.value(HttpHeaders.acceptHeader));
      switch (request.uri.path) {
        case '/robots.txt':
          response.statusCode = robotsStatus;
          if (robotsStatus == 200) response.write(robotsTxt);
        case '/v1/files/photo/image':
          response.headers.contentType = ContentType('image', 'jpeg');
          response.add([1, 2, 3]);
        default:
          response.headers.contentType = ContentType.html;
          response.write('<html>sign in</html>');
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Future<T> withFetcher<T>(Future<T> Function(PoliteFetcher) body) {
    final inner = HttpClient();
    return HttpOverrides.runZoned(() async {
      final fetcher = PoliteFetcher(
        site: FetchSite(
          host: FetchSite.photos.host,
          pathPrefix: FetchSite.photos.pathPrefix,
          pageMarker: FetchSite.photos.pageMarker,
          statePath: '${dir.path}/state.json',
          accept: FetchSite.photos.accept,
          robotsRequired: false,
        ),
        policy: const FetchPolicy(
          minDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );
      try {
        await fetcher.prepare();
        return await body(fetcher);
      } finally {
        fetcher.close();
      }
    }, createHttpClient: (_) => _ToLocal(inner, server.port));
  }

  const photo = 'https://ireland.apollo.olxcdn.com/v1/files/photo/image';

  test('a photo server without robots.txt allows the photos', () async {
    final bytes = await withFetcher((f) => f.getImage(Uri.parse(photo)));

    expect(bytes, [1, 2, 3]);
    expect(accepts.last, FetchSite.photos.accept);
  });

  test('its robots.txt is still obeyed when it has one', () async {
    robotsStatus = 200;
    await expectLater(
      withFetcher((f) => f.getImage(Uri.parse(photo))),
      throwsA(
        isA<FetchDisallowed>().having(
          (e) => e.reason,
          'reason',
          endsWith('(Disallow: /)'),
        ),
      ),
    );
  });

  test(
    'a longer Allow opens the photos under a Disallow of the rest',
    () async {
      robotsStatus = 200;
      robotsTxt = 'User-agent: *\nDisallow: /\nAllow: /v1/files/\n';
      final bytes = await withFetcher((f) => f.getImage(Uri.parse(photo)));

      expect(bytes, [1, 2, 3]);
    },
  );

  test('a page instead of a photo is a block', () async {
    await expectLater(
      withFetcher(
        (f) => f.getImage(
          Uri.parse('https://ireland.apollo.olxcdn.com/v1/files/x/image'),
        ),
      ),
      throwsA(isA<FetchBlocked>()),
    );
  });

  test('only the photo CDN', () async {
    await expectLater(
      withFetcher((f) => f.getImage(Uri.parse('https://example.com/a.jpg'))),
      throwsA(isA<FetchRefused>()),
    );
  });
}
