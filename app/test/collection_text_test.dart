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
  group('next collection (minute 40 of every 4th hour, UTC)', () {
    test('later the same block', () {
      expect(
        nextCollection(DateTime.utc(2026, 10, 19, 12, 10)),
        DateTime.utc(2026, 10, 19, 12, 40),
      );
    });

    test('just after a run, the next block', () {
      expect(
        nextCollection(DateTime.utc(2026, 10, 19, 12, 40)),
        DateTime.utc(2026, 10, 19, 16, 40),
      );
      expect(
        nextCollection(DateTime.utc(2026, 10, 19, 14, 5)),
        DateTime.utc(2026, 10, 19, 16, 40),
      );
    });

    test('across midnight', () {
      expect(
        nextCollection(DateTime.utc(2026, 10, 19, 22, 50)),
        DateTime.utc(2026, 10, 20, 0, 40),
      );
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

  test('durations read as minutes and seconds', () {
    expect(durationText(const Duration(seconds: 151)), '2 min 31 s');
    expect(durationText(const Duration(seconds: 42)), '42 s');
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
}
