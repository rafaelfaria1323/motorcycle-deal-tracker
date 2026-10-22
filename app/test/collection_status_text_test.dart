import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/database_usage.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/github_token.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/collection_status_text.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  group('token', () {
    test('missing or refused needs Rafael', () {
      final missing = tokenText(
        const GithubToken(state: GithubTokenState.missing),
        now,
      );
      expect(missing.warning, isTrue);
      expect(missing.text, contains('Vault'));
      final refused = tokenText(
        const GithubToken(state: GithubTokenState.refused, httpStatus: 401),
        now,
      );
      expect(refused.warning, isTrue);
      expect(refused.text, contains('HTTP 401'));
    });

    test('warns in the last 14 days', () {
      GithubToken expiring(int days) => GithubToken(
        state: GithubTokenState.ok,
        expiresAt: now.add(Duration(days: days, hours: 1)),
      );
      expect(tokenText(expiring(60), now).warning, isFalse);
      expect(tokenText(expiring(60), now).text, contains('faltam 60 dias'));
      expect(tokenText(expiring(13), now).warning, isTrue);
      expect(tokenText(expiring(13), now).text, contains('Crie um novo'));
      expect(tokenText(expiring(1), now).text, contains('falta 1 dia'));
      expect(tokenText(expiring(0), now).text, contains('termina hoje'));
    });

    test('a token without an end date', () {
      final text = tokenText(
        const GithubToken(state: GithubTokenState.ok),
        now,
      );
      expect(text.warning, isFalse);
      expect(text.text, contains('sem data de fim'));
    });

    test('an unknown state reads as refused', () {
      expect(
        GithubToken.fromJson({'state': 'odd'}).state,
        GithubTokenState.refused,
      );
    });
  });

  group('site budget', () {
    const budget = SiteBudget(requestsToday: 47);

    test('today\'s requests, from a run today', () {
      final text = siteBudgetText(
        'standvirtual',
        budget,
        reportedAt: now.subtract(const Duration(hours: 1)),
        now: now,
      );
      expect(text.text, 'Standvirtual: 47 pedidos hoje (UTC)');
      expect(text.warning, isFalse);
    });

    test('a run from yesterday used nothing of today', () {
      expect(
        siteBudgetText(
          'olx',
          budget,
          reportedAt: now.subtract(const Duration(days: 1)),
          now: now,
        ).text,
        'OLX: 0 pedidos hoje (UTC)',
      );
    });

    test('no daily cap: many requests are not a warning, one is singular', () {
      final many = siteBudgetText(
        'olx',
        const SiteBudget(requestsToday: 500),
        reportedAt: now,
        now: now,
      );
      expect(many.warning, isFalse);
      expect(
        siteBudgetText(
          'olx',
          const SiteBudget(requestsToday: 1),
          reportedAt: now,
          now: now,
        ).text,
        'OLX: 1 pedido hoje (UTC)',
      );
    });

    test('a pause still running, and one that is over', () {
      final paused = siteBudgetText(
        'olx',
        SiteBudget(
          requestsToday: 3,
          pausedUntil: now.add(const Duration(hours: 5)),
        ),
        reportedAt: now,
        now: now,
      );
      expect(paused.warning, isTrue);
      expect(paused.text, startsWith('OLX: em pausa até '));
      expect(
        siteBudgetText(
          'olx',
          SiteBudget(
            requestsToday: 3,
            pausedUntil: now.subtract(const Duration(minutes: 1)),
          ),
          reportedAt: now,
          now: now,
        ).warning,
        isFalse,
      );
    });

    test('reads the run\'s JSON (an older run\'s daily_limit ignored)', () {
      expect(
        SiteBudget.fromJson({
          'requests_today': 47,
          'daily_limit': 120,
          'paused_until': '2026-10-22T08:00:00.000Z',
        }),
        SiteBudget(
          requestsToday: 47,
          pausedUntil: DateTime.utc(2026, 10, 22, 8),
        ),
      );
    });
  });

  test('run labels', () {
    expect(runStatusLabel('ok'), 'Correu bem');
    expect(runStatusLabel('blocked'), 'Bloqueada');
    expect(runStatusLabel('failed'), 'Falhou');
  });

  group('database usage', () {
    const mb = 1024 * 1024;

    test('the size against the free plan, red from 80 %', () {
      final low = databaseUsageText(
        const DatabaseUsage(bytes: 42 * mb + mb ~/ 3, tables: []),
      );
      expect(low.text, 'A base de dados ocupa 42,3 MB de 500 MB (8 %).');
      expect(low.warning, isFalse);
      final high = databaseUsageText(
        const DatabaseUsage(bytes: 400 * mb, tables: []),
      );
      expect(
        high.text,
        startsWith('A base de dados ocupa 400,0 MB de 500 MB (80 %).'),
      );
      expect(high.text, contains('só deixa ler'));
      expect(high.warning, isTrue);
    });

    test('the biggest tables, or nothing', () {
      expect(
        biggestTablesText(
          const DatabaseUsage(
            bytes: 50 * mb,
            tables: [
              (name: 'listings', bytes: 30 * mb),
              (name: 'alerts', bytes: mb ~/ 2),
            ],
          ),
        ),
        'Maiores tabelas: listings 30,0 MB, alerts 0,5 MB',
      );
      expect(
        biggestTablesText(const DatabaseUsage(bytes: mb, tables: [])),
        isNull,
      );
    });

    test('reads the database function\'s answer', () {
      expect(
        DatabaseUsage.fromJson({
          'database_bytes': 2048,
          'tables': [
            {'name': 'listings', 'bytes': 1024},
          ],
        }),
        const DatabaseUsage(
          bytes: 2048,
          tables: [(name: 'listings', bytes: 1024)],
        ),
      );
    });
  });
}
