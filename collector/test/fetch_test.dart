import 'dart:io';

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

    test('the longest matching rule decides; Allow wins a tie', () {
      final cdn = RobotsRules.parse(
        'User-agent: *\nDisallow: /\nAllow: /v1/files/\n'
        'Disallow: /v1/files/private/\nAllow: /tie\nDisallow: /tie\n',
      );
      expect(cdn.isAllowed('/v1/files/x/image'), isTrue);
      expect(cdn.decidingRule('/v1/files/x/image'), 'Allow: /v1/files/');
      expect(cdn.isAllowed('/v1/files/private/x'), isFalse);
      expect(cdn.isAllowed('/other'), isFalse);
      expect(cdn.decidingRule('/other'), 'Disallow: /');
      expect(cdn.isAllowed('/tie'), isTrue);
      expect(RobotsRules.parse('').decidingRule('/x'), 'no rule');
    });

    test('compares addresses and rules percent-decoded (RFC 9309)', () {
      final sorted = RobotsRules.parse(
        'User-agent: *\nDisallow: /*search[order]\n'
        'Disallow: /a%2Fb\nDisallow: /motos/caf%c3%a9\nDisallow: /x%2A\n',
      );
      // Our addresses carry the brackets encoded, as Uri writes them.
      expect(
        sorted.isAllowed('/motos/yamaha?search%5Border%5D=created_at:desc'),
        isFalse,
      );
      expect(sorted.isAllowed('/motos/yamaha?search%5Bfilter%5D=1'), isTrue);
      expect(sorted.isAllowed('/a/b'), isFalse);
      expect(sorted.isAllowed('/motos/café'), isFalse);
      expect(sorted.isAllowed('/motos/caf%C3%A9'), isFalse);
      // An encoded * is a plain character, not "anything".
      expect(sorted.isAllowed('/x*'), isFalse);
      expect(sorted.isAllowed('/xy'), isTrue);
    });

    test(r'$ ends a rule only as its last character', () {
      final ends = RobotsRules.parse(
        'User-agent: *\nDisallow: /*.json\$\nDisallow: /price\$list\n',
      );
      expect(ends.isAllowed('/motos/a.json'), isFalse);
      expect(ends.isAllowed('/motos/a.json?x=1'), isTrue);
      expect(ends.isAllowed('/price\$list'), isFalse);
      expect(ends.isAllowed('/price'), isTrue);
    });

    test('rules of other bots do not apply to us', () {
      expect(rules.isAllowed('/'), isTrue);
      expect(rules.isAllowed('/x/payment/'), isTrue);
    });
  });

  group('address checks', () {
    const site = FetchSite.standvirtual;

    test('accepts a motorcycle search over https', () {
      expect(
        urlProblem(
          Uri.parse('https://www.standvirtual.com/motos/yamaha'),
          site: site,
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
        'https://www.standvirtual.com:8443/motos/x',
        'https://www.standvirtual.com/motos/../api/x',
      ]) {
        expect(urlProblem(Uri.parse(bad), site: site), isNotNull, reason: bad);
      }
    });

    test('OLX: only the motorcycles category', () {
      const olx = FetchSite.olx;
      expect(
        urlProblem(
          Uri.parse(
            'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/',
          ),
          site: olx,
        ),
        isNull,
      );
      expect(
        urlProblem(
          Uri.parse('https://www.olx.pt/carros-motos-e-barcos/carros/bmw/'),
          site: olx,
        ),
        isNotNull,
      );
      expect(
        urlProblem(Uri.parse('https://www.olx.pt/api/v1/offers'), site: olx),
        isNotNull,
      );
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

    test('robots.txt is kept across days and through JSON', () {
      final read = DateTime.utc(2026, 10, 19, 8);
      final state = FetchState(
        day: '2026-10-19',
        robots: robots,
        robotsReadAt: read,
      );

      final copy = FetchState.fromJson(state.toJson()).rolledTo('2026-10-20');

      expect(copy.robots, robots);
      expect(copy.robotsReadAt, read);
    });

    test('robots.txt is used for less than 24 hours', () {
      final read = DateTime.utc(2026, 10, 19, 8);
      final state = FetchState(
        day: '2026-10-19',
        robots: robots,
        robotsReadAt: read,
      );
      const day = Duration(hours: 24);

      expect(state.keptRobots(day, read), robots);
      expect(
        state.keptRobots(day, read.add(const Duration(hours: 23, minutes: 59))),
        robots,
      );
      expect(state.keptRobots(day, read.add(day)), isNull);
      // A clock that went back: read again.
      expect(
        state.keptRobots(day, read.subtract(const Duration(minutes: 1))),
        isNull,
      );
      expect(FetchState(day: '2026-10-19').keptRobots(day, read), isNull);
    });

    test('reports today\'s requests and a pause still running', () {
      final state = FetchState(
        day: '2026-10-19',
        requests: 47,
        blockedAt: DateTime.utc(2026, 10, 19, 8),
      );
      const policy = FetchPolicy();

      expect(state.report(policy, DateTime.utc(2026, 10, 19, 20)), {
        'requests_today': 47,
        'paused_until': '2026-10-20T08:00:00.000Z',
      });
      // The next day: nothing used yet, the pause is over.
      expect(state.report(policy, DateTime.utc(2026, 10, 20, 9)), {
        'requests_today': 0,
        'paused_until': null,
      });
    });

    test('a missing or damaged state file reads as none', () async {
      final dir = await Directory.systemTemp.createTemp('fetch_state');
      addTearDown(() => dir.delete(recursive: true));
      expect(await readFetchState('${dir.path}/none.json'), isNull);
      final damaged = File('${dir.path}/bad.json')..writeAsStringSync('{');
      expect(await readFetchState(damaged.path), isNull);
      final good = File('${dir.path}/good.json')
        ..writeAsStringSync('{"day": "2026-10-19", "requests": 5}');
      expect((await readFetchState(good.path))!.requests, 5);
    });
  });
}
