import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  test('exit code 0 is ok whatever the log says', () {
    expect(runStatus(0, 'Stopped, the site pushed back'), 'ok');
  });

  test('a push-back or a pause is a block', () {
    expect(runStatus(2, 'Stopped, the site pushed back: HTTP 429'), 'blocked');
    expect(runStatus(2, 'Not fetched: paused until 2026-10-20'), 'blocked');
  });

  test('anything else is a failure', () {
    expect(runStatus(2, 'Database error: timeout'), 'failed');
    expect(runStatus(65, 'Read issue: page-2.html: bad JSON'), 'failed');
  });

  group('partial', () {
    const end =
        '== all sites ==\n'
        'Scored 900 listing(s) in 4200 ms.\n'
        'Alerts created: 2\n'
        'Notifications sent: 2 (3 to devices)\n'
        'Refresh finished in 1500 s, 1 site(s) failed.\n'
        'make: *** [Makefile:88: refresh] Error 75\n';

    test('only passing fetch failures, and the run got to its end', () {
      expect(
        runStatus(
          2,
          '== standvirtual ==\n'
          'Stored 2 new, 30 already stored, 0 duplicate(s) in the input.\n'
          '== olx ==\n'
          'Retrying once in 60 s: https://www.olx.pt/x: timed out\n'
          'Failed: https://www.olx.pt/x: timed out\n'
          '$end',
        ),
        'partial',
      );
      expect(
        runStatus(
          2,
          '== standvirtual ==\n'
          'Failed: https://www.standvirtual.com/motos/y: HTTP 502\n'
          '== olx ==\n'
          'Failed: https://www.olx.pt/x: Connection reset by peer\n'
          '$end',
        ),
        'partial',
      );
    });

    test('any other problem, or a run that stopped early, is a failure', () {
      const olxFailed =
          '== olx ==\n'
          'Failed: https://www.olx.pt/x: timed out\n';
      for (final other in [
        'Read issue: page-2.html: bad JSON\n',
        'Database error: timeout\n',
        'Not a search results page: no state\n',
      ]) {
        expect(runStatus(2, '$olxFailed$other$end'), 'failed');
      }
      // A database error after the sites, before the notifications.
      expect(
        runStatus(
          2,
          '$olxFailed== all sites ==\n'
          'Database error: canceling statement due to statement timeout\n',
        ),
        'failed',
      );
      // Unhandled: no error line of ours, no end.
      expect(
        runStatus(2, '${olxFailed}Unhandled exception:\nBad state: x\n'),
        'failed',
      );
      // No site's error line at all.
      expect(runStatus(2, end), 'failed');
    });
  });

  test('the scoring time is read from finishRun\'s line', () {
    expect(
      scoringMs(
        '== all sites ==\n'
        'Duplicates flagged: 3\n'
        '  Scored 912 listing(s) in 41230 ms.\n',
      ),
      41230,
    );
    expect(scoringMs('Scored 89 listing(s).\n'), isNull);
    expect(scoringMs(''), isNull);
  });

  test('the tail keeps the last lines', () {
    final log = List.generate(100, (i) => 'line $i').join('\n');
    final tail = logTail(log, lines: 3);

    expect(tail, 'line 97\nline 98\nline 99');
  });

  test('the tail of a short or empty log is all of it', () {
    expect(logTail(''), '');
    expect(logTail('one\ntwo\n\n'), 'one\ntwo');
  });

  test('the tail is cut to the last characters', () {
    final log = List.generate(5, (i) => 'line $i').join('\n');

    expect(logTail(log, maxChars: 6), 'line 4');
  });

  test('sums what each site did', () {
    const log =
        '== standvirtual ==\n'
        'Stored 2 new, 30 already stored, 0 duplicate(s) in the input.\n'
        'Price changes: 1\n'
        'Removal skipped: a page is missing (use --force to override).\n'
        '== olx ==\n'
        '  Stored 1 new, 50 already stored, 1 duplicate(s) in the input.\n'
        'Price changes: 0\n'
        'Removed: 3\n'
        '== all sites ==\n'
        'Alerts created: 4\n'
        'Site-reported price cuts updated: 7\n';

    expect(runCounts(log), {
      'new': 3,
      'price_changes': 1,
      'removed': 3,
      'alerts': 4,
    });
    expect(runCounts('Database error: timeout'), isEmpty);
    expect(runCounts('x Removed: 2\nNot Stored 5 new'), isEmpty);
  });

  test('reads the requests each site used', () {
    const log =
        'Requests used: standvirtual=15\n'
        'Scored 89 listing(s).\n'
        // Older runs wrote the cap after the count.
        'Requests used: olx=9 (limit 20)\n';

    expect(requestsUsed(log), {'standvirtual': 15, 'olx': 9});
    expect(requestsUsed('no counts here'), isEmpty);
  });

  test('reads what each search cost and gave', () {
    const report = (
      search: 'https://www.olx.pt/b',
      spans: null,
      pages: 0,
      ads: 0,
      matched: 0,
      inFull: false,
    );
    final log = [
      'Mapped 80, rejected 0.',
      'Search (standvirtual): yamaha-mt-07, yamaha-r7 · read 3 of 3 page(s) '
          '· 87 ad(s), 40 followed · in full',
      // The line importBatch writes.
      searchReportLine('olx', report, null),
      'Requests used: olx=9',
    ].join('\n');

    expect(searchesRead(log), [
      {
        'site': 'standvirtual',
        'search': 'yamaha-mt-07, yamaha-r7',
        'pages': 3,
        'spans': 3,
        'ads': 87,
        'followed': 40,
        'in_full': true,
      },
      {
        'site': 'olx',
        'search': 'https://www.olx.pt/b',
        'pages': 0,
        'spans': null,
        'ads': 0,
        'followed': 0,
        'in_full': false,
      },
    ]);
    expect(searchesRead('Search yield: 9 of 80 ad(s)'), isEmpty);
  });

  test('the GitHub run page comes from the job\'s variables', () {
    expect(
      githubRunUrl({
        'GITHUB_SERVER_URL': 'https://github.com',
        'GITHUB_REPOSITORY': 'rafael/tracker',
        'GITHUB_RUN_ID': '42',
      }),
      'https://github.com/rafael/tracker/actions/runs/42',
    );
    expect(githubRunUrl({}), isNull);
  });
}
