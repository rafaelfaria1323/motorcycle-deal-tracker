import 'package:flutter_test/flutter_test.dart';
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

    test('every 2 hours in the afternoon', () {
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 12)),
        DateTime.utc(2026, 12, 1, 14),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 19, 5)),
        DateTime.utc(2026, 12, 1, 20),
      );
    });

    test('midnight, then 08:00, then 12:00', () {
      expect(
        nextCollection(DateTime.utc(2026, 12, 1, 20, 10)),
        DateTime.utc(2026, 12, 2),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 2, 0, 1)),
        DateTime.utc(2026, 12, 2, 8),
      );
      expect(
        nextCollection(DateTime.utc(2026, 12, 2, 9)),
        DateTime.utc(2026, 12, 2, 12),
      );
    });

    test('in summer time the same Lisbon hours are an hour earlier in UTC', () {
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

  test('requests per site against the limit', () {
    expect(
      requestsText({'standvirtual': 15, 'olx': 9}),
      'Standvirtual 15 de 20 · OLX 9 de 20',
    );
    expect(requestsText(const {}), isNull);
  });

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
