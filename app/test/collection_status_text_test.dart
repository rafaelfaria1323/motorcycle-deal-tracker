import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
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
        GithubToken.fromJson(const {'state': 'odd'}).state,
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
        SiteBudget.fromJson(const {
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

  test('search lines', () {
    SearchRead read({int? spans = 3, int pages = 3, bool inFull = true}) =>
        SearchRead(
          site: 'olx',
          search: 'yamaha-mt-07, yamaha-r7',
          pages: pages,
          spans: spans,
          ads: 80,
          followed: 9,
          inFull: inFull,
        );

    expect(
      searchReadText(read()),
      'OLX · yamaha-mt-07, yamaha-r7: 3 de 3 páginas, 80 anúncios (9 dos '
      'modelos acompanhados)',
    );
    expect(
      searchReadText(read(pages: 2, inFull: false)),
      endsWith(
        '2 de 3 páginas, 80 anúncios (9 dos modelos acompanhados) · '
        'não lida toda',
      ),
    );
    expect(
      searchReadText(read(spans: 1, pages: 1)),
      contains('1 de 1 página,'),
    );
    expect(
      searchReadText(read(spans: null, pages: 0, inFull: false)),
      'OLX · yamaha-mt-07, yamaha-r7: não lida nesta recolha',
    );
    expect(
      SearchRead.fromJson(const {
        'site': 'standvirtual',
        'search': 'honda-cb650r',
        'pages': 2,
        'spans': null,
        'ads': 40,
        'followed': 38,
        'in_full': false,
      }),
      const SearchRead(
        site: 'standvirtual',
        search: 'honda-cb650r',
        pages: 2,
        spans: null,
        ads: 40,
        followed: 38,
        inFull: false,
      ),
    );
  });

  test('run labels', () {
    expect(runStatusLabel('ok'), 'Correu bem');
    expect(runStatusLabel('partial'), 'Incompleta');
    expect(runStatusLabel('blocked'), 'Bloqueada');
    expect(runStatusLabel('failed'), 'Falhou');
  });

  test('the scoring time warns past half the database\'s limit', () {
    expect(scoringText(const Duration(milliseconds: 4210)), (
      text: 'Pontuações em 4,2 s',
      warning: false,
    ));
    expect(scoringText(const Duration(seconds: 30)).warning, isFalse);
    expect(scoringText(const Duration(milliseconds: 41230)), (
      text:
          'As pontuações demoraram 41,2 s, mais de metade do limite de 60 s '
          'da base de dados.',
      warning: true,
    ));
  });

  group('failures', () {
    CollectorRun run(String status, DateTime started, List<String> problems) =>
        CollectorRun(
          status: status,
          startedAt: started,
          finishedAt: started.add(const Duration(minutes: 20)),
          problems: problems,
        );

    test('causes from the error lines', () {
      expect(
        failureCause('olx: Failed: https://www.olx.pt/x: timed out'),
        'Sem resposta ou erro do site (tempo esgotado, HTTP 5xx)',
      );
      expect(
        failureCause('standvirtual: Stopped, the site pushed back: HTTP 429'),
        'O site recusou os pedidos',
      );
      expect(
        failureCause('olx: Not fetched: paused until 2026-10-22'),
        'Em pausa ou pedido não permitido',
      );
      expect(
        failureCause('Database error: canceling statement'),
        'Erro da base de dados',
      );
      for (final line in [
        'olx: Read issue: page-2.html: bad JSON',
        'olx: Cannot read the saved pages: gone (samples/olx)',
        'olx: Not a search results page: no state',
      ]) {
        expect(failureCause(line), 'Páginas que não foi possível ler');
      }
      expect(failureCause('Missing SUPABASE_URL'), 'Outro erro');
    });

    test('by site and cause, most frequent first, a run once each', () {
      final runs = [
        run('partial', DateTime.utc(2026, 10, 26, 13, 2), [
          'olx: Failed: https://www.olx.pt/a: timed out',
          'olx: Failed: https://www.olx.pt/b: timed out',
        ]),
        run('ok', DateTime.utc(2026, 10, 26, 11), const []),
        run('failed', DateTime.utc(2026, 10, 25, 19), [
          'standvirtual: Failed: https://www.standvirtual.com/motos/y: '
              'HTTP 502',
          'Database error: canceling statement',
        ]),
        run('partial', DateTime.utc(2026, 10, 24, 7), [
          'olx: Failed: https://www.olx.pt/a: HTTP 504',
        ]),
        run('failed', DateTime.utc(2026, 10, 23, 23), const []),
      ];

      expect(failureHistoryText(runs), [
        'OLX · Sem resposta ou erro do site (tempo esgotado, HTTP 5xx): 2 '
            'recolhas, a última a 26/10 às 13:02',
        'Standvirtual · Sem resposta ou erro do site (tempo esgotado, HTTP '
            '5xx): 1 recolha, a 25/10 às 19:00',
        'Erro da base de dados: 1 recolha, a 25/10 às 19:00',
        'Outro erro: 1 recolha, a 23/10 às 23:00',
      ]);
      expect(failureShareText(runs), '4 de 5 recolhas não correram bem');
      expect(failureHistoryText(runs.sublist(1, 2)), isEmpty);
      expect(failureShareText(runs.sublist(1, 2)), 'A recolha correu bem');
      expect(
        failureShareText([runs[1], runs[1]]),
        'As 2 recolhas correram todas bem',
      );
      expect(
        failureShareText(runs.sublist(0, 1)),
        '1 de 1 recolha não correu bem',
      );
    });

    test('in English', () {
      const en = AppLanguage.english;
      final runs = [
        run('partial', DateTime.utc(2026, 10, 26, 13, 2), [
          'olx: Failed: https://www.olx.pt/a: timed out',
        ]),
        run('ok', DateTime.utc(2026, 10, 26, 11), const []),
        run('partial', DateTime.utc(2026, 10, 24, 7), [
          'olx: Failed: https://www.olx.pt/a: HTTP 504',
        ]),
      ];
      expect(runStatusLabel('partial', language: en), 'Incomplete');
      expect(failureHistoryText(runs, language: en), [
        'OLX · No response or site error (timeout, HTTP 5xx): 2 collections, '
            'the last on 26/10 at 13:02',
      ]);
      expect(
        failureShareText(runs, language: en),
        '2 of 3 collections went wrong',
      );
      expect(
        failureShareText(runs.sublist(1, 2), language: en),
        'The collection went well',
      );
      expect(
        scoringText(const Duration(milliseconds: 4210), language: en).text,
        'Scores in 4.2 s',
      );
    });
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
        DatabaseUsage.fromJson(const {
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
