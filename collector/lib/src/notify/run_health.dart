import 'notification_text.dart';

/// A recorded run as the health check sees it: its status (`ok`,
/// `blocked`, `partial` or `failed`, see `runStatus`) and its problems
/// (runProblems, `site: line`).
typedef RunOutcome = ({String status, List<String> problems});

/// The notification (Web Push, to the admins' devices) for a change in the
/// collection's health, from the last [runs], newest first (this run, then
/// the two before it, when there are), or null when nothing changed: a
/// problem is reported once, not on every run, and so is the recovery. A
/// `partial` run counts as fine unless one of its sites also failed in
/// the run before (`partial` or `failed`): one lost search is read again
/// by the next run. A tap opens "Estado da recolha".
Map<String, Object?>? runHealthMessage(
  List<RunOutcome> runs, {
  NotificationLanguage language = NotificationLanguage.portuguese,
}) {
  final current = _seenAs(runs, 0);
  final previous = runs.length > 1 ? _seenAs(runs, 1) : null;
  if (current == previous) return null;
  if (current == 'ok' && previous == null) return null;
  final again = current == 'failed' && runs.first.status == 'partial';
  final (title, advice) = switch (current) {
    'ok' => (language.recovered, null),
    'blocked' => (language.blocked, language.blockedAdvice),
    _ => (
      again ? language.failedTwice : language.failed,
      language.failedAdvice,
    ),
  };
  return {
    'title': title,
    'body': [if (current != 'ok') ...runs.first.problems, ?advice].join('\n'),
    'url': '/#/collection-status',
    'tag': 'run-health',
    'language': language.code,
  };
}

/// The status of `runs[i]` as the admins are told it: a `partial` run is
/// `failed` when a site of it also failed in the run before, else `ok`.
String _seenAs(List<RunOutcome> runs, int i) {
  final run = runs[i];
  if (run.status != 'partial') return run.status;
  final before = i + 1 < runs.length ? runs[i + 1] : null;
  if (before == null || !const {'partial', 'failed'}.contains(before.status)) {
    return 'ok';
  }
  final sites = problemSites(before.problems);
  return problemSites(run.problems).any(sites.contains) ? 'failed' : 'ok';
}

/// The sites named in a run's [problems] (`olx: Failed: …` -> olx).
Set<String> problemSites(List<String> problems) => {
  for (final p in problems)
    if (RegExp(r'^(\w+): (.*)$').firstMatch(p) case final m?
        when _problemMarks.any(m.group(2)!.startsWith))
      m.group(1)!,
};

/// refresh.dart's error lines.
const _problemMarks = [
  'Not fetched: ',
  'Stopped, the site pushed back: ',
  'Failed: ',
  'Cannot read the saved pages: ',
  'Not a search results page: ',
  'Read issue: ',
  'Database error: ',
];

/// What went wrong in a run, from refresh.dart's error lines, each with the
/// site it happened on (`standvirtual: Failed: …`). Without any, the last
/// line that is not make's own (an error before the sites started). At most
/// [max] lines, each cut to [maxChars].
List<String> runProblems(String log, {int max = 5, int maxChars = 200}) {
  final lines = log.split('\n').map((l) => l.trim()).where((l) => l != '');
  final problems = <String>[];
  String? site;
  for (final line in lines) {
    final section = RegExp(r'^== (.+) ==$').firstMatch(line);
    if (section != null) {
      final name = section.group(1)!;
      site = name == 'all sites' ? null : name;
    } else if (_problemMarks.any(line.startsWith)) {
      problems.add(site == null ? line : '$site: $line');
    }
  }
  if (problems.isEmpty) {
    final last = lines.lastWhere(
      (l) => !l.startsWith('make') && !l.startsWith('Refresh finished'),
      orElse: () => '',
    );
    if (last != '') problems.add(last);
  }
  return [
    for (final p in problems.take(max))
      p.length > maxChars ? '${p.substring(0, maxChars - 1)}…' : p,
  ];
}
