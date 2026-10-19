/// The outcome of one scheduled run, from its exit code and its log.
/// make turns every failure into exit code 2, so a block is recognised by the
/// fetcher's own wording.
String runStatus(int exitCode, String log) {
  if (exitCode == 0) return 'ok';
  const blockedMarks = [
    'the site pushed back',
    'paused until',
    'daily limit of',
  ];
  if (blockedMarks.any(log.contains)) return 'blocked';
  return 'failed';
}

/// The end of the log, which is where the counts and errors are.
String logTail(String log, {int lines = 40, int maxChars = 4000}) {
  final all = log.trimRight().split('\n');
  final tail = all.length > lines ? all.sublist(all.length - lines) : all;
  final text = tail.join('\n');
  return text.length > maxChars ? text.substring(text.length - maxChars) : text;
}
