import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/collection_text.dart';

CollectorRun run(int seconds, {Map<String, int> requests = const {}}) {
  final start = DateTime.utc(2026, 10, 19, 12, 40);
  return CollectorRun(
    status: 'ok',
    startedAt: start,
    finishedAt: start.add(Duration(seconds: seconds)),
    requests: requests,
  );
}

void main() {
  group('next collection (on the Lisbon hours)', () {
    test('the coming hour', () {
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 11, 50)),
        DateTime.utc(2026, 12, 1, 12),
      );
    });

    test('every 2 hours from 08:00 to 22:00', () {
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 8)),
        DateTime.utc(2026, 12, 1, 10),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 12)),
        DateTime.utc(2026, 12, 1, 14),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 20, 10)),
        DateTime.utc(2026, 12, 1, 22),
      );
    });

    test('midnight, then 08:00, then 10:00', () {
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 22, 10)),
        DateTime.utc(2026, 12, 2),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 2, 0, 1)),
        DateTime.utc(2026, 12, 2, 8),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 2, 9)),
        DateTime.utc(2026, 12, 2, 10),
      );
    });

    test('in summer time the same Lisbon hours are an hour earlier in UTC', () {
      expect(
        nextCollection(DateTime.utc(2026, 7, 1, 19)),
        DateTime.utc(2026, 7, 1, 21),
      );
      expect(
        nextCollection(DateTime.utc(2026, 7, 1, 21)),
        DateTime.utc(2026, 7, 1, 23),
      );
      expect(
        nextCollection(DateTime.utc(2026, 7, 2, 0)),
        DateTime.utc(2026, 7, 2, 7),
      );
    });

    test('summer time follows the EU rule', () {
      // 2026: from 29 March to 25 October, 01:00 UTC.
      expect(lisbonOffset(DateTime.utc(2026, 3, 29, 0, 59)), Duration.zero);
      expect(
        lisbonOffset(DateTime.utc(2026, 3, 29, 1)),
        const Duration(hours: 1),
      );
      expect(
        lisbonOffset(DateTime.utc(2026, 10, 25, 0, 59)),
        const Duration(hours: 1),
      );
      expect(lisbonOffset(DateTime.utc(2026, 10, 25, 1)), Duration.zero);
    });

    test('the text gives the day and time', () {
      expect(
        nextCollectionText(DateTime.now()),
        startsWith('Próxima recolha: '),
      );
    });
  });

  group('Mais\' collection line (F.5)', () {
    final now = DateTime.utc(2026, 12, 1, 11);
    final next = nextCollectionText(now);
    CollectorRun ended(Duration ago, {String status = 'ok'}) => CollectorRun(
      status: status,
      startedAt: now.subtract(ago).subtract(const Duration(minutes: 5)),
      finishedAt: now.subtract(ago),
    );

    test('an anonymous session (no run to read) hears only the next run', () {
      final line = collectionLine(null, now);
      expect(line.health, CollectorHealth.unknown);
      expect(line.title, next);
      expect(line.title, startsWith('Próxima recolha: '));
      expect(line.subtitle, isNull);
    });

    test('a good or partial run: when it was, then the next', () {
      for (final status in ['ok', 'partial']) {
        final line = collectionLine(
          ended(const Duration(minutes: 40), status: status),
          now,
        );
        expect(line.health, CollectorHealth.ok);
        expect(line.title, 'Última recolha há 40 min');
        expect(line.subtitle, next);
      }
    });

    test('an old run says prices may be out of date', () {
      final line = collectionLine(ended(const Duration(hours: 13)), now);
      expect(line.health, CollectorHealth.stale);
      expect(line.title, 'Sem atualizações recentes');
      expect(
        line.subtitle,
        'A última recolha foi há 13 h. Os preços podem estar '
        'desatualizados.\n$next',
      );
    });

    test('a blocked run says the site paused it, not the schedule', () {
      final line = collectionLine(
        ended(const Duration(hours: 2), status: 'blocked'),
        now,
      );
      expect(line.health, CollectorHealth.blocked);
      expect(line.title, 'Recolha bloqueada pelo site');
      expect(line.subtitle, contains('(há 2 h)'));
      expect(line.subtitle, isNot(contains('Próxima recolha')));
    });

    test('a failed run says when, then the next', () {
      final line = collectionLine(
        ended(const Duration(hours: 2), status: 'failed'),
        now,
      );
      expect(line.health, CollectorHealth.failed);
      expect(line.title, 'A última recolha falhou');
      expect(line.subtitle, 'Há 2 h · $next');
    });

    test('in English', () {
      const english = AppLanguage.english;
      final nextEn = nextCollectionText(now, language: english);
      expect(nextEn, startsWith('Next collection: '));
      expect(collectionLine(null, now, language: english).title, nextEn);
      final ok = collectionLine(
        ended(const Duration(minutes: 40)),
        now,
        language: english,
      );
      expect(ok.title, 'Last collection 40 min ago');
      expect(ok.subtitle, nextEn);
      final failed = collectionLine(
        ended(const Duration(hours: 2), status: 'failed'),
        now,
        language: english,
      );
      expect(failed.title, 'The last collection failed');
      expect(failed.subtitle, '2 h ago · $nextEn');
    });
  });

  test('how long ago, in minutes, hours or days', () {
    final now = DateTime.utc(2026, 10, 19, 12);
    expect(
      agoText(now.subtract(const Duration(minutes: 25)), now: now),
      'há 25 min',
    );
    expect(agoText(now.subtract(const Duration(hours: 3)), now: now), 'há 3 h');
    expect(
      agoText(now.subtract(const Duration(days: 3)), now: now),
      'há 3 dias',
    );
  });

  test('a time slightly in the future (clock skew) reads as 0 min', () {
    final now = DateTime.utc(2026, 10, 19, 12);
    expect(agoText(now.add(const Duration(minutes: 3)), now: now), 'há 0 min');
  });

  test('hours turn into days at exactly 48 h', () {
    final now = DateTime.utc(2026, 10, 19, 12);
    expect(
      agoText(now.subtract(const Duration(hours: 47, minutes: 59)), now: now),
      'há 47 h',
    );
    expect(
      agoText(now.subtract(const Duration(hours: 48)), now: now),
      'há 2 dias',
    );
  });

  test('durations read as minutes and seconds', () {
    expect(durationText(const Duration(seconds: 151)), '2 min 31 s');
    expect(durationText(const Duration(seconds: 42)), '42 s');
  });

  test('what the last run did, plural and singular, zeros left out', () {
    expect(
      runCountsText({'new': 3, 'price_changes': 2, 'removed': 4, 'alerts': 5}),
      '3 anúncios novos, 2 preços alterados, 4 anúncios removidos, 5 alertas',
    );
    expect(
      runCountsText({'new': 1, 'price_changes': 1, 'removed': 1, 'alerts': 1}),
      '1 anúncio novo, 1 preço alterado, 1 anúncio removido, 1 alerta',
    );
    expect(
      runCountsText({'new': 0, 'price_changes': 2, 'alerts': 0}),
      '2 preços alterados',
    );
    expect(
      runCountsText({'new': 0, 'removed': 0}),
      'Sem anúncios novos nem alterações',
    );
    expect(runCountsText(const {}), isNull);
  });

  test('requests per site', () {
    expect(
      requestsText({'standvirtual': 15, 'olx': 9}),
      'Pedidos: Standvirtual 15 · OLX 9',
    );
    expect(requestsText(const {}), isNull);
  });

  test('this month\'s requests per site, with the average per run', () {
    expect(
      monthRequestsText([
        run(60, requests: {'standvirtual': 15, 'olx': 9}),
        run(60, requests: {'standvirtual': 40, 'olx': 12}),
        run(60), // an older run without counts
      ]),
      'Pedidos este mês: Standvirtual 55 (28 por recolha) · '
      'OLX 21 (11 por recolha)',
    );
    expect(monthRequestsText([run(60)]), isNull);
  });

  test(
    'requests per local day, newest first, days without counts left out',
    () {
      CollectorRun at(DateTime start, Map<String, int> requests) =>
          CollectorRun(
            status: 'ok',
            startedAt: start,
            finishedAt: start.add(const Duration(minutes: 5)),
            requests: requests,
          );
      final now = DateTime(2026, 10, 22, 15);

      expect(
        dailyRequestsText([
          at(DateTime(2026, 10, 22, 14), {'standvirtual': 15, 'olx': 9}),
          at(DateTime(2026, 10, 22, 8), {'standvirtual': 30, 'olx': 10}),
          at(DateTime(2026, 10, 21, 20), {'standvirtual': 12}),
          at(DateTime(2026, 10, 19, 12), {'olx': 4}),
          at(DateTime(2026, 10, 18, 12), const {}),
        ], now),
        [
          'Hoje: Standvirtual 45 · OLX 19',
          'Ontem: Standvirtual 12',
          '19/10: OLX 4',
        ],
      );
      expect(dailyRequestsText(const [], now), isEmpty);
    },
  );

  test('a month of runs in whole minutes, with set-up time', () {
    expect(estimatedMinutes(run(151)), 4);
    expect(estimatedMinutes(run(20)), 1);
    expect(
      monthUsageText([run(151), run(130)]),
      '2 recolhas este mês, cerca de 7 min de GitHub Actions',
    );
  });

  test('capitalize only changes the first letter', () {
    expect(capitalize('há 3 h'), 'Há 3 h');
    expect(capitalize('Já'), 'Já');
    expect(capitalize(''), '');
  });
}
