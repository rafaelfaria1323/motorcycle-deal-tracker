import 'notification_text.dart';

/// The notification (Web Push, to the admins' devices) for a change in the
/// collection's health between the [previous] run's status and this run's
/// [current] one (`ok`, `blocked`, `failed`, see `runStatus`), or null when
/// nothing changed: a problem is reported once, not on every run, and so
/// is the recovery. A tap opens "Estado da recolha".
Map<String, Object?>? runHealthMessage({
  required String? previous,
  required String current,
  required String log,
  NotificationLanguage language = NotificationLanguage.portuguese,
}) {
  if (current == previous) return null;
  if (current == 'ok' && previous == null) return null;
  final problems = current == 'ok' ? const <String>[] : runProblems(log);
  final (title, advice) = switch (current) {
    'ok' => (language.recovered, null),
    'blocked' => (language.blocked, language.blockedAdvice),
    _ => (language.failed, language.failedAdvice),
  };
  return {
    'title': title,
    'body': [...problems, ?advice].join('\n'),
    'url': '/#/collection-status',
    'tag': 'run-health',
    'language': language.code,
  };
}

/// What went wrong in a run, from refresh.dart's error lines, each with the
/// site it happened on (`standvirtual: Failed: …`). Without any, the last
/// line that is not make's own (an error before the sites started). At most
/// [max] lines, each cut to [maxChars].
List<String> runProblems(String log, {int max = 5, int maxChars = 200}) {
  const marks = [
    'Not fetched: ',
    'Stopped, the site pushed back: ',
    'Failed: ',
    'Cannot read the saved pages: ',
    'Not a search results page: ',
    'Read issue: ',
    'Database error: ',
  ];
  final lines = log.split('\n').map((l) => l.trim()).where((l) => l != '');
  final problems = <String>[];
  String? site;
  for (final line in lines) {
    final section = RegExp(r'^== (.+) ==$').firstMatch(line);
    if (section != null) {
      final name = section.group(1)!;
      site = name == 'all sites' ? null : name;
    } else if (marks.any(line.startsWith)) {
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
