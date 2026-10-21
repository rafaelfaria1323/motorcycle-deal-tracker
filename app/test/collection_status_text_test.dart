import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
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
    const budget = SiteBudget(requestsToday: 47, dailyLimit: 120);

    test('today\'s requests, from a run today', () {
      final text = siteBudgetText(
        'standvirtual',
        budget,
        reportedAt: now.subtract(const Duration(hours: 1)),
        now: now,
      );
      expect(text.text, 'Standvirtual: 47 de 120 pedidos hoje');
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
        'OLX: 0 de 120 pedidos hoje',
      );
    });

    test('the whole day used is a warning', () {
      expect(
        siteBudgetText(
          'olx',
          const SiteBudget(requestsToday: 120, dailyLimit: 120),
          reportedAt: now,
          now: now,
        ).warning,
        isTrue,
      );
    });

    test('a pause still running, and one that is over', () {
      final paused = siteBudgetText(
        'olx',
        SiteBudget(
          requestsToday: 3,
          dailyLimit: 120,
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
            dailyLimit: 120,
            pausedUntil: now.subtract(const Duration(minutes: 1)),
          ),
          reportedAt: now,
          now: now,
        ).warning,
        isFalse,
      );
    });

    test('reads the run\'s JSON', () {
      expect(
        SiteBudget.fromJson({
          'requests_today': 47,
          'daily_limit': 120,
          'paused_until': '2026-10-22T08:00:00.000Z',
        }),
        SiteBudget(
          requestsToday: 47,
          dailyLimit: 120,
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
}
