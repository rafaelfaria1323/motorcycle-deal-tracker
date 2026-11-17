import 'dart:convert';
import 'dart:io';

import '../adapters/source_adapter.dart';
import '../notify/run_health.dart';
import 'source_batch.dart';

/// How one site's part of a refresh ended.
enum SiteOutcome {
  /// Read and imported (its read issues aside, see [SiteReport.issues]).
  ok,

  /// A request failed after its retry ([SiteReport.problem]): a timeout,
  /// a dropped connection, an HTTP error. What was saved was imported.
  failed,

  /// The site pushed back, or is still paused after it did.
  blocked,

  /// Anything else: our own rules refused, the saved pages or the
  /// database could not be read or written.
  error,
}

/// What one site did in a refresh (N.57): written by refresh.dart as it
/// goes, read by report_run.dart, so the run's status no longer depends
/// on the wording of the log.
class SiteReport {
  SiteReport();

  factory SiteReport.fromJson(Map<String, dynamic> json) => SiteReport()
    ..outcome = SiteOutcome.values.byName(json['outcome'] as String)
    ..problem = json['problem'] as String?
    ..requests = json['requests'] as int
    ..issues.addAll([
      for (final i in (json['issues'] as List).cast<Map<String, dynamic>>())
        (
          text: i['text'] as String,
          kind: IssueKind.values.byName(i['kind'] as String),
        ),
    ])
    ..searches.addAll((json['searches'] as List).cast<Map<String, dynamic>>());

  SiteOutcome outcome = .ok;

  /// The error line of an outcome that isn't ok, as the log shows it
  /// ("Failed: … timed out").
  String? problem;

  /// Requests sent to the site, robots.txt included.
  int requests = 0;

  /// The input's read issues, each with what kind it is.
  final issues = <({String text, IssueKind kind})>[];

  /// Per planned search: `{search, pages, spans, ads, followed, in_full}`.
  final searches = <Map<String, Object?>>[];

  Map<String, Object?> toJson() => {
    'outcome': outcome.name,
    'problem': problem,
    'requests': requests,
    'issues': [
      for (final i in issues) {'text': i.text, 'kind': i.kind.name},
    ],
    'searches': searches,
  };
}

/// What a whole refresh did: each site in the order read, the counts over
/// all of them and whether the run got to its end.
class RunReport {
  RunReport();

  factory RunReport.fromJson(Map<String, dynamic> json) => RunReport()
    ..sites.addAll({
      for (final MapEntry(:key, :value)
          in (json['sites'] as Map<String, dynamic>).entries)
        key: SiteReport.fromJson(value as Map<String, dynamic>),
    })
    ..counts.addAll((json['counts'] as Map<String, dynamic>).cast())
    ..scoringMs = json['scoring_ms'] as int?
    ..steps.addAll({
      for (final MapEntry(:key, :value)
          in (json['steps_ms'] as Map<String, dynamic>? ?? const {}).entries)
        key: (value as Map<String, dynamic>).cast<String, int>(),
    })
    ..finished = json['finished'] as bool;

  final sites = <String, SiteReport>{};

  /// `new`, `price_changes`, `removed`, `alerts`, summed over the sites; a
  /// key is absent when no site's import got that far.
  final counts = <String, int>{};

  /// How long the scoring took; null when the run didn't get there.
  int? scoringMs;

  /// How long each step took, in milliseconds (N.118): per part of the
  /// run, each site in the order read and [allSites] for what runs once
  /// (`{'olx': {'fetch': 74000, 'save': 3600}, 'all': {'scores': 2100}}`).
  /// A step that runs twice adds up.
  final steps = <String, Map<String, int>>{};

  /// The part of [steps] for what runs once for every site.
  static const allSites = 'all';

  /// True once scores, alerts and notifications were done.
  bool finished = false;

  void count(String key, int n) => counts[key] = (counts[key] ?? 0) + n;

  /// Adds [took] to [step] of [part] in [steps].
  void addStep(String part, String step, Duration took) {
    final times = steps.putIfAbsent(part, () => <String, int>{});
    times[step] = (times[step] ?? 0) + took.inMilliseconds;
  }

  /// "Step times: olx fetch 74.0 s, save 3.6 s · all scores 2.1 s", for the
  /// log; null when nothing was timed.
  String? stepsLine() {
    if (steps.isEmpty) return null;
    String part(String name, Map<String, int> times) {
      final each = [
        for (final MapEntry(:key, :value) in times.entries)
          '$key ${(value / 1000).toStringAsFixed(1)} s',
      ];
      return '$name ${each.join(', ')}';
    }

    final parts = [
      for (final MapEntry(:key, :value) in steps.entries) part(key, value),
    ];
    return 'Step times: ${parts.join(' · ')}';
  }

  Map<String, Object?> toJson() => {
    'sites': {
      for (final MapEntry(:key, :value) in sites.entries) key: value.toJson(),
    },
    'counts': counts,
    'scoring_ms': scoringMs,
    'steps_ms': steps,
    'finished': finished,
  };

  /// Written whole after each site and at the end, so a run that stops
  /// halfway still leaves what it did.
  Future<void> writeTo(String path) =>
      File(path).writeAsString(jsonEncode(toJson()), flush: true);

  /// What [importBatch] adds for [site]: its read issues, its searches
  /// and what it stored, changed and removed.
  void addImport(
    String site, {
    required List<ParseIssue> issues,
    required List<SearchReport> searches,
    required Map<String, String> labels,
  }) {
    final report = sites.putIfAbsent(site, SiteReport.new);
    for (final issue in issues) {
      report.issues.add((text: '$issue', kind: issue.kind));
    }
    for (final r in searches) {
      report.searches.add({
        'search': labels[r.search] ?? r.search,
        'pages': r.pages,
        'spans': r.spans,
        'ads': r.ads,
        'followed': r.matched,
        'in_full': r.inFull,
      });
    }
  }
}

/// Runs [work] and adds how long it took to [step] of [part] in
/// [report]'s step times, also when it throws; without a report it only
/// runs it.
Future<T> timeStep<T>(
  RunReport? report,
  String part,
  String step,
  Future<T> Function() work,
) async {
  if (report == null) return await work();
  final watch = Stopwatch()..start();
  try {
    return await work();
  } finally {
    report.addStep(part, step, watch.elapsed);
  }
}

/// The report a refresh left at [path]; null when there is none or it
/// can't be read (the run stopped before writing it): the log is read
/// instead.
Future<RunReport?> readRunReport(String? path) async {
  if (path == null) return null;
  try {
    return RunReport.fromJson(
      jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
    );
  } on Object {
    return null;
  }
}

/// The status of a run from its [report] and exit code, with the rules
/// of `runStatus`: `failed` when no site was read; `blocked` when a site
/// pushed back; `ok` when nothing went wrong; `partial` when the run
/// finished and its only problems were passing ones (a site's failed
/// request and the pages it left unread, or a page served without its
/// results while another search of that site was read in full).
String reportStatus(int exitCode, RunReport report) {
  if (report.sites.isEmpty) return 'failed';
  final sites = report.sites.values;
  if (sites.any((s) => s.outcome == .blocked)) return 'blocked';
  final clean = sites.every((s) => s.outcome == .ok && s.issues.isEmpty);
  if (clean) return exitCode == 0 && report.finished ? 'ok' : 'failed';
  if (!report.finished) return 'failed';

  bool passing(SiteReport site) {
    if (site.outcome == .error) return false;
    final readInFull = site.searches.any((s) => s['in_full'] == true);
    return site.issues.every(
      (issue) => switch (issue.kind) {
        .pagesUnread => site.outcome == .failed,
        .notResultsPage => readInFull,
        .other => false,
      },
    );
  }

  return sites.every(passing) ? 'partial' : 'failed';
}

/// A run's problems as `collector_runs.problems` keeps them, from its
/// [report]: each site's error line and read issues (`olx: Failed: …`,
/// `olx: Read issue: …`), [noSiteProblem] when no site was read. At most
/// [max] lines, each cut to [maxChars].
List<String> reportProblems(
  RunReport report, {
  int max = 5,
  int maxChars = 200,
}) {
  final problems = [
    if (report.sites.isEmpty) noSiteProblem,
    for (final MapEntry(key: site, value: r) in report.sites.entries) ...[
      for (final issue in r.issues) '$site: Read issue: ${issue.text}',
      if (r.problem case final problem?) '$site: $problem',
    ],
    if (report.sites.isNotEmpty &&
        !report.finished &&
        report.sites.values.every((s) => s.problem == null && s.issues.isEmpty))
      'The run stopped before its scores and alerts (see the GitHub run).',
  ];
  return [
    for (final p in problems.take(max))
      p.length > maxChars ? '${p.substring(0, maxChars - 1)}…' : p,
  ];
}
