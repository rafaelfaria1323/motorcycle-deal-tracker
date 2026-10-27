import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  group('runHealthMessage', () {
    const problems = [
      'standvirtual: Stopped, the site pushed back: HTTP 429',
      'olx: Database error: timeout',
    ];
    RunOutcome run(String status, [List<String> p = problems]) =>
        (status: status, problems: status == 'ok' ? const [] : p);

    test('the same status as last time sends nothing', () {
      for (final s in ['ok', 'blocked', 'failed']) {
        expect(runHealthMessage([run(s), run(s)]), isNull);
      }
    });

    test('the first run ever is news only when it went wrong', () {
      expect(runHealthMessage([run('ok')]), isNull);
      expect(
        runHealthMessage([run('failed')])?['title'],
        '⚠️ A recolha de anúncios falhou.',
      );
    });

    test('a failure says what went wrong on which site', () {
      expect(runHealthMessage([run('failed'), run('ok')]), {
        'title': '⚠️ A recolha de anúncios falhou.',
        'body':
            'standvirtual: Stopped, the site pushed back: HTTP 429\n'
            'olx: Database error: timeout\n'
            'Os preços na app podem ficar desatualizados até a recolha voltar '
            'a funcionar.',
        'url': '/#/collection-status',
        'tag': 'run-health',
      });
    });

    test('a block says the site waits 24 hours', () {
      expect(
        runHealthMessage([run('blocked'), run('failed')]),
        containsPair(
          'title',
          '⛔ Um site recusou os pedidos da recolha de anúncios.',
        ),
      );
      expect(
        runHealthMessage([run('blocked', const []), run('ok')])?['body'],
        'A recolha desse site fica em pausa durante 24 h e volta a tentar '
        'automaticamente.',
      );
    });

    test('the recovery is told once', () {
      for (final s in ['blocked', 'failed']) {
        final message = runHealthMessage([run('ok'), run(s)]);
        expect(
          message?['title'],
          '✅ A recolha de anúncios voltou a funcionar.',
        );
        expect(message?['body'], '');
        expect(runHealthMessage([run('ok'), run('ok'), run(s)]), isNull);
      }
    });

    group('a partial run', () {
      const olx = ['olx: Failed: https://www.olx.pt/x: timed out'];
      const standvirtual = [
        'standvirtual: Failed: https://www.standvirtual.com/motos/y: HTTP 502',
      ];

      test('once is not news', () {
        expect(runHealthMessage([run('partial', olx), run('ok')]), isNull);
        expect(runHealthMessage([run('partial', olx)]), isNull);
        // The run before failed on another site.
        expect(
          runHealthMessage([
            run('partial', olx),
            run('partial', standvirtual),
            run('ok'),
          ]),
          isNull,
        );
      });

      test('the same site failing two runs in a row is told once', () {
        final message = runHealthMessage([
          run('partial', olx),
          run('partial', olx),
          run('ok'),
        ]);
        expect(
          message?['title'],
          '⚠️ A recolha de anúncios falhou duas vezes seguidas.',
        );
        expect(message?['body'], startsWith('${olx.single}\n'));
        // After a failure on the site (a read issue), too.
        expect(
          runHealthMessage([
            run('partial', olx),
            run('failed', ['olx: Read issue: page-2.html: bad JSON']),
          ]),
          isNull, // already told, as a failure
        );
        // The third time it was already told.
        expect(
          runHealthMessage([
            run('partial', olx),
            run('partial', olx),
            run('partial', olx),
          ]),
          isNull,
        );
      });

      test('a block before it is not the same failure', () {
        expect(
          runHealthMessage([
            run('partial', olx),
            run('blocked', ['olx: Stopped, the site pushed back: HTTP 403']),
          ])?['title'],
          '✅ A recolha de anúncios voltou a funcionar.',
        );
      });

      test('the recovery after two in a row is told; after one, not', () {
        expect(
          runHealthMessage([
            run('ok'),
            run('partial', olx),
            run('partial', olx),
          ])?['title'],
          '✅ A recolha de anúncios voltou a funcionar.',
        );
        expect(
          runHealthMessage([run('ok'), run('partial', olx), run('ok')]),
          isNull,
        );
      });

      test('a failure after one is told at once', () {
        expect(
          runHealthMessage([run('failed'), run('partial', olx)])?['title'],
          '⚠️ A recolha de anúncios falhou.',
        );
      });
    });
  });

  test('problemSites names the sites of the error lines', () {
    expect(
      problemSites([
        'olx: Failed: timed out',
        'standvirtual: Read issue: x',
        'Database error: scores',
        'Missing SUPABASE_URL: x',
      ]),
      {'olx', 'standvirtual'},
    );
  });

  group('runProblems', () {
    test('read issues keep their site and cause after a partial import', () {
      const log =
          '== olx ==\n'
          'Read issue: page-2.html: bad JSON\n'
          'Stored 1 new, 0 already stored, 0 duplicate(s) in the input.\n'
          '== all sites ==\n'
          'Notifications sent: 0 (0 to devices)\n';

      expect(runProblems(log), ['olx: Read issue: page-2.html: bad JSON']);
    });

    test('error lines with their site; other lines and Skipped ignored', () {
      const log =
          '== standvirtual ==\n'
          '  search: Yamaha MT-07\n'
          'Skipped: Honda CB650R has no standvirtual search\n'
          'Not fetched: daily limit of 120 requests\n'
          '== olx ==\n'
          '  Failed: HTTP 500\n'
          'Not a search results page: == no state ==\n'
          'Cannot read the saved pages: gone (samples/olx)\n'
          '== all sites ==\n'
          'Database error: scores\n'
          'Refresh finished in 90 s, 2 site(s) failed.\n'
          'make: *** [Makefile:88: refresh] Error 70\n';

      expect(runProblems(log), [
        'standvirtual: Not fetched: daily limit of 120 requests',
        'olx: Failed: HTTP 500',
        'olx: Not a search results page: == no state ==',
        'olx: Cannot read the saved pages: gone (samples/olx)',
        'Database error: scores',
      ]);
    });

    test('without error lines, the last line that is not make\'s', () {
      const log =
          'Missing SUPABASE_URL\n'
          'Refresh finished in 0 s.\n'
          'make: *** [Makefile:88: refresh] Error 1\n\n';

      expect(runProblems(log), ['Missing SUPABASE_URL']);
      expect(runProblems('make: *** Error 1'), isEmpty);
      expect(runProblems(''), isEmpty);
    });

    test('at most max lines, each cut to maxChars', () {
      final log = List.generate(8, (i) => 'Failed: $i ${'x' * 30}').join('\n');
      final problems = runProblems(log, max: 3, maxChars: 12);

      expect(problems, ['Failed: 0 x…', 'Failed: 1 x…', 'Failed: 2 x…']);
      expect(runProblems('Failed: short', maxChars: 13), ['Failed: short']);
    });
  });
}
