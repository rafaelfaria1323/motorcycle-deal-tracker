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
