import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';

CollectorRun run(String status, DateTime finished) => CollectorRun(
  status: status,
  startedAt: finished.subtract(const Duration(minutes: 5)),
  finishedAt: finished,
);

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);

  test('no run means nothing to show', () {
    expect(collectorHealth(null, now), CollectorHealth.unknown);
  });

  test('a recent ok run is ok', () {
    final r = run('ok', now.subtract(const Duration(hours: 5)));
    expect(collectorHealth(r, now), CollectorHealth.ok);
  });

  test('an ok run older than 12 hours is stale', () {
    final r = run('ok', now.subtract(const Duration(hours: 13)));
    expect(collectorHealth(r, now), CollectorHealth.stale);
  });

  test('a partial run is fine, but still stale when old', () {
    final recent = now.subtract(const Duration(hours: 1));
    expect(collectorHealth(run('partial', recent), now), CollectorHealth.ok);
    expect(
      collectorHealth(
        run('partial', now.subtract(const Duration(hours: 13))),
        now,
      ),
      CollectorHealth.stale,
    );
  });

  test('blocked and failed are reported whatever their age', () {
    final recent = now.subtract(const Duration(hours: 1));
    expect(
      collectorHealth(run('blocked', recent), now),
      CollectorHealth.blocked,
    );
    expect(collectorHealth(run('failed', recent), now), CollectorHealth.failed);
  });
}
