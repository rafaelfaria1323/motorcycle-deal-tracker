import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

SiteReport _site({
  SiteOutcome outcome = SiteOutcome.ok,
  String? problem,
  List<IssueKind> issues = const [],
  bool inFull = true,
}) => SiteReport()
  ..outcome = outcome
  ..problem = problem
  ..requests = 4
  ..issues.addAll([
    for (final kind in issues)
      (text: '#0: page.html: ${kind.name}', kind: kind),
  ])
  ..searches.add({
    'search': 'MT-07',
    'pages': 2,
    'spans': 2,
    'ads': 60,
    'followed': 9,
    'in_full': inFull,
  });

RunReport _run(Map<String, SiteReport> sites, {bool finished = true}) =>
    RunReport()
      ..sites.addAll(sites)
      ..finished = finished;

void main() {
  group('reportStatus', () {
    test('ok: every site clean, the run finished and exited 0', () {
      final run = _run({'olx': _site(), 'standvirtual': _site()});
      expect(reportStatus(0, run), 'ok');
      // A crash after the sites (the scores failed) is not ok.
      expect(reportStatus(70, run), 'failed');
      expect(
        reportStatus(0, _run({'olx': _site()}, finished: false)),
        'failed',
      );
    });

    test('failed: no site was read', () {
      expect(reportStatus(0, _run({})), 'failed');
      expect(reportProblems(_run({})), [noSiteProblem]);
    });

    test('blocked: a site pushed back or is paused, whatever else', () {
      final run = _run({
        'olx': _site(outcome: .blocked, problem: 'Not fetched: paused'),
        'standvirtual': _site(outcome: .error, problem: 'Database error: x'),
      });
      expect(reportStatus(75, run), 'blocked');
    });

    test('partial: a failed request and the pages it left unread', () {
      final run = _run({
        'olx': _site(
          outcome: .failed,
          problem: 'Failed: timed out',
          issues: [.pagesUnread],
        ),
        'standvirtual': _site(),
      });
      expect(reportStatus(75, run), 'partial');
      // Not when the run never got to its scores and alerts.
      expect(reportStatus(75, _run(run.sites, finished: false)), 'failed');
    });

    test('pages unread without a failed request are not passing', () {
      expect(
        reportStatus(
          65,
          _run({
            'olx': _site(issues: [.pagesUnread]),
          }),
        ),
        'failed',
      );
    });

    test('a page without its results passes only beside a search read in '
        'full', () {
      expect(
        reportStatus(
          65,
          _run({
            'olx': _site(issues: [.notResultsPage]),
          }),
        ),
        'partial',
      );
      expect(
        reportStatus(
          65,
          _run({
            'olx': _site(issues: [.notResultsPage], inFull: false),
          }),
        ),
        'failed',
      );
    });

    test('any other read issue or error fails the run', () {
      expect(
        reportStatus(
          65,
          _run({
            'olx': _site(issues: [.other]),
          }),
        ),
        'failed',
      );
      expect(
        reportStatus(
          70,
          _run({
            'olx': _site(outcome: .error, problem: 'Database error: x'),
            'standvirtual': _site(),
          }),
        ),
        'failed',
      );
    });
  });

  group('reportProblems', () {
    test("each site's issues and error line, as the app shows them", () {
      final run = _run({
        'olx': _site(
          outcome: .failed,
          problem: 'Failed: https://www.olx.pt/x: timed out',
          issues: [.pagesUnread],
        ),
        'standvirtual': _site(),
      });
      final problems = reportProblems(run);
      expect(problems, [
        'olx: Read issue: #0: page.html: pagesUnread',
        'olx: Failed: https://www.olx.pt/x: timed out',
      ]);
      // The health check names the site from them, as from the log's.
      expect(problemSites(problems), {'olx'});
    });

    test('a run that stopped after clean sites says so', () {
      expect(reportProblems(_run({'olx': _site()}, finished: false)), [
        'The run stopped before its scores and alerts (see the GitHub run).',
      ]);
    });

    test('at most 5, each cut to 200 characters', () {
      final run = _run({
        'olx': _site(
          outcome: .error,
          problem: 'Database error: ${'x' * 300}',
          issues: List.filled(6, IssueKind.other),
        ),
      });
      expect(reportProblems(run), hasLength(5));
      final long = reportProblems(run, max: 7).last;
      expect(long, hasLength(200));
      expect(long, endsWith('…'));
    });
  });

  group('the report file', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('run_report'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads back what was written', () async {
      final run =
          _run({
              'olx': _site(
                outcome: .failed,
                problem: 'Failed: x',
                issues: [.pagesUnread, .notResultsPage],
              ),
            })
            ..count('new', 2)
            ..count('new', 3)
            ..count('alerts', 1)
            ..scoringMs = 1200;
      final path = '${dir.path}/report.json';
      await run.writeTo(path);
      final read = (await readRunReport(path))!;
      expect(jsonEncode(read.toJson()), jsonEncode(run.toJson()));
      expect(read.counts, {'new': 5, 'alerts': 1});
      expect(read.sites['olx']!.issues.last.kind, IssueKind.notResultsPage);
      expect(read.sites['olx']!.requests, 4);
      expect(read.scoringMs, 1200);
      expect(read.finished, isTrue);
    });

    test('none, missing or damaged: null, so the log is read', () async {
      expect(await readRunReport(null), isNull);
      expect(await readRunReport('${dir.path}/none.json'), isNull);
      final damaged = File('${dir.path}/damaged.json')
        ..writeAsStringSync('{"sites": ');
      expect(await readRunReport(damaged.path), isNull);
    });
  });

  test('an import adds its issues and searches under the site', () {
    final report = RunReport()
      ..addImport(
        'olx',
        issues: const [
          ParseIssue(1, 'a.html: bad', search: 's'),
          ParseIssue(0, 's: 1 of 2 page(s) saved', kind: .pagesUnread),
        ],
        searches: const [
          (search: 's', spans: 2, pages: 1, ads: 40, matched: 7, inFull: false),
          (
            search: 't',
            spans: null,
            pages: 0,
            ads: 0,
            matched: 0,
            inFull: false,
          ),
        ],
        labels: const {'s': 'Yamaha MT-07'},
      );
    final site = report.sites['olx']!;
    expect(site.issues, [
      (text: '#1: a.html: bad', kind: IssueKind.other),
      (text: '#0: s: 1 of 2 page(s) saved', kind: IssueKind.pagesUnread),
    ]);
    expect(site.searches, [
      {
        'search': 'Yamaha MT-07',
        'pages': 1,
        'spans': 2,
        'ads': 40,
        'followed': 7,
        'in_full': false,
      },
      {
        'search': 't',
        'pages': 0,
        'spans': null,
        'ads': 0,
        'followed': 0,
        'in_full': false,
      },
    ]);
  });
}
