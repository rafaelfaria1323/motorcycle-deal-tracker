import '../notify/run_health.dart';

/// The outcome of one scheduled run, from its exit code and its log: `ok`,
/// `blocked`, `partial` or `failed`. make turns every failure into exit
/// code 2, so a block is recognised by the fetcher's own wording.
///
/// `partial`: the run got to its end (scores, alerts and notifications)
/// and its only problems were a site's passing fetch failures (`Failed: `,
/// a timeout, a dropped connection or an HTTP error still there after the
/// retry): the other searches and sites were read, and the lost ones are
/// read again by the next run. The admins hear of it only when the same
/// site fails again in the next run (runHealthMessage).
String runStatus(int exitCode, String log) {
  if (exitCode == 0) return 'ok';
  const blockedMarks = ['the site pushed back', 'paused until'];
  if (blockedMarks.any(log.contains)) return 'blocked';
  final problems = runProblems(log, max: 1 << 20, maxChars: 1 << 20);
  final passing =
      log.contains(RegExp(r'^\s*Notifications sent: ', multiLine: true)) &&
      problems.isNotEmpty &&
      problems.every(RegExp(r'^\w+: Failed: ').hasMatch);
  return passing ? 'partial' : 'failed';
}

/// How long the run's scoring took (finishRun's `Scored N listing(s) in
/// M ms.`), or null when the run didn't get there.
int? scoringMs(String log) {
  final matches = RegExp(
    r'^\s*Scored \d+ listing\(s\) in (\d+) ms\.',
    multiLine: true,
  ).allMatches(log);
  return matches.isEmpty ? null : int.parse(matches.last.group(1)!);
}

/// The end of the log, which is where the counts and errors are.
String logTail(String log, {int lines = 40, int maxChars = 4000}) {
  final all = log.trimRight().split('\n');
  final tail = all.length > lines ? all.sublist(all.length - lines) : all;
  final text = tail.join('\n');
  return text.length > maxChars ? text.substring(text.length - maxChars) : text;
}

/// What a run did, summed over the sites, from importBatch's and finishRun's
/// log lines: `new` (Stored N new), `price_changes`, `removed` and `alerts`.
/// A key is left out when its line is missing (e.g. no full import, no
/// removal); empty when the run got that far nowhere.
Map<String, int> runCounts(String log) {
  const patterns = {
    'new': r'^\s*Stored (\d+) new',
    'price_changes': r'^\s*Price changes: (\d+)',
    'removed': r'^\s*Removed: (\d+)',
    'alerts': r'^\s*Alerts created: (\d+)',
  };
  final counts = <String, int>{};
  for (final MapEntry(:key, :value) in patterns.entries) {
    for (final m in RegExp(value, multiLine: true).allMatches(log)) {
      counts[key] = (counts[key] ?? 0) + int.parse(m.group(1)!);
    }
  }
  return counts;
}

/// Requests each site used in a run, from refresh.dart's
/// `Requests used: <site>=<n>` lines; empty when the log has none.
Map<String, int> requestsUsed(String log) => {
  for (final m in RegExp(r'Requests used: (\w+)=(\d+)').allMatches(log))
    m.group(1)!: int.parse(m.group(2)!),
};

/// What each search cost and gave in a run (R.1), from importBatch's
/// `Search (<site>): ...` lines (searchReportLine), in the log's order:
/// `{site, search, pages, spans, ads, followed, in_full}`, `spans` null
/// when the search's first page wasn't saved. Empty when the log has none.
List<Map<String, Object?>> searchesRead(String log) => [
  for (final m in RegExp(
    r'^\s*Search \((\w+)\): (.+) · read (\d+) of (\d+|\?) page\(s\) · '
    r'(\d+) ad\(s\), (\d+) followed · (in full|not in full)\s*$',
    multiLine: true,
  ).allMatches(log))
    {
      'site': m.group(1),
      'search': m.group(2),
      'pages': int.parse(m.group(3)!),
      'spans': int.tryParse(m.group(4)!),
      'ads': int.parse(m.group(5)!),
      'followed': int.parse(m.group(6)!),
      'in_full': m.group(7) == 'in full',
    },
];

/// The GitHub Actions run's page, from the variables every job has; null
/// outside Actions.
String? githubRunUrl(Map<String, String> env) {
  final server = env['GITHUB_SERVER_URL'];
  final repo = env['GITHUB_REPOSITORY'];
  final id = env['GITHUB_RUN_ID'];
  if (server == null || repo == null || id == null) return null;
  return '$server/$repo/actions/runs/$id';
}
