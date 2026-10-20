/// The Telegram message for a change in the collection's health between the
/// [previous] run's status and this run's [current] one (`ok`, `blocked`,
/// `failed`, see `runStatus`), or null when nothing changed: a problem is
/// reported once, not every 4 hours, and so is the recovery.
String? runHealthMessage({
  required String? previous,
  required String current,
  required String log,
}) {
  if (current == previous) return null;
  if (current == 'ok') {
    return previous == null
        ? null
        : '✅ A recolha de anúncios voltou a funcionar.';
  }
  final problems = runProblems(log);
  final details = problems.isEmpty ? '' : '\n\n${problems.join('\n')}';
  if (current == 'blocked') {
    return '⛔ Um site recusou os pedidos da recolha de anúncios.$details\n\n'
        'A recolha desse site fica em pausa durante 24 h e volta a tentar '
        'automaticamente.';
  }
  return '⚠️ A recolha de anúncios falhou.$details\n\n'
      'Os preços na app podem ficar desatualizados até a recolha voltar a '
      'funcionar. O registo completo está no GitHub Actions.';
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
