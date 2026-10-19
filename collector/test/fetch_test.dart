import 'package:collector/collector.dart';
import 'package:test/test.dart';

const robots = '''
User-agent: msnbot
Crawl-delay: 10

User-agent: trovitBot
Disallow: /

User-agent: *
Disallow: /account/
Disallow: /api/
Disallow: */rss/
Disallow: /catalog/*/*/
Allow: /

User-agent: AdsBot-Google
User-agent: ProbelySPDR
Disallow: */payment/
''';

void main() {
  group('robots.txt rules', () {
    final rules = RobotsRules.parse(robots);

    test('blocks what the * group disallows', () {
      expect(rules.isAllowed('/account/x'), isFalse);
      expect(rules.isAllowed('/api/v1'), isFalse);
      expect(rules.isAllowed('/motos/rss/'), isFalse);
      expect(rules.isAllowed('/catalog/a/b/'), isFalse);
    });

    test('allows searches and listings', () {
      expect(
        rules.isAllowed('/motos/yamaha/mt-07?search%5Border%5D=1'),
        isTrue,
      );
      expect(rules.isAllowed('/motos/anuncio/x-IDabc.html'), isTrue);
    });

    test('rules of other bots do not apply to us', () {
      expect(rules.isAllowed('/'), isTrue);
      expect(rules.isAllowed('/x/payment/'), isTrue);
    });
  });

  group('address checks', () {
    const host = 'www.standvirtual.com';

    test('accepts a motorcycle search over https', () {
      expect(
        urlProblem(
          Uri.parse('https://www.standvirtual.com/motos/yamaha'),
          host: host,
        ),
        isNull,
      );
    });

    test('refuses everything else', () {
      for (final bad in [
        'http://www.standvirtual.com/motos/yamaha',
        'https://example.com/motos/yamaha',
        'https://www.standvirtual.com/carros/bmw',
        'https://user:pw@www.standvirtual.com/motos/x',
      ]) {
        expect(urlProblem(Uri.parse(bad), host: host), isNotNull, reason: bad);
      }
    });
  });

  group('fetch state', () {
    test('the count restarts on a new day but a block is remembered', () {
      final blocked = DateTime.utc(2026, 10, 19, 8);
      final state = FetchState(
        day: '2026-10-19',
        requests: 40,
        blockedAt: blocked,
      );

      final next = state.rolledTo('2026-10-20');

      expect(next.requests, 0);
      expect(next.blockedAt, blocked);
      expect(state.rolledTo('2026-10-19').requests, 40);
    });

    test('survives a round trip through JSON', () {
      final state = FetchState(
        day: '2026-10-19',
        requests: 3,
        blockedAt: DateTime.utc(2026, 10, 19, 8),
      );

      final copy = FetchState.fromJson(state.toJson());

      expect(copy.day, '2026-10-19');
      expect(copy.requests, 3);
      expect(copy.blockedAt, state.blockedAt);
    });
  });
}
