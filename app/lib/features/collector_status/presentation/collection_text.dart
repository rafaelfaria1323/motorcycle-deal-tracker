import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';

/// The collection runs at minute 30 of every hour, UTC (cron '30 * * * *'
/// in .github/workflows/collect.yml; keep them in step). Temporary while
/// testing the schedule; normally minute 40 of every 4th hour.
const _hourStep = 1;
const _minute = 30;

/// Requests allowed per site and run (FetchPolicy.maxRequestsPerRun).
const requestsPerRunLimit = 20;

/// The next scheduled collection after [now].
DateTime nextCollection(DateTime now) {
  final utc = now.toUtc();
  var next = DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour - utc.hour % _hourStep,
    _minute,
  );
  while (!next.isAfter(utc)) {
    next = next.add(const Duration(hours: _hourStep));
  }
  return next;
}

/// "Próxima recolha: hoje às 20:40" (local time). GitHub starts scheduled
/// runs late when it is busy, hence the note.
String nextCollectionText(DateTime now) {
  final next = nextCollection(now).toLocal();
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final day = DateTime(next.year, next.month, next.day);
  final when = switch (day.difference(today).inDays) {
    0 => 'hoje',
    1 => 'amanhã',
    _ => Formatters.date(next),
  };
  final time =
      '${next.hour.toString().padLeft(2, '0')}:'
      '${next.minute.toString().padLeft(2, '0')}';
  return 'Próxima recolha: $when às $time (o GitHub pode atrasá-la alguns '
      'minutos)';
}

/// "há 3 h" (or minutes, or days).
String agoText(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 48) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} dias';
}

/// Starts a sentence: "há 3 h" -> "Há 3 h".
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "2 min 31 s".
String durationText(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return minutes == 0 ? '$seconds s' : '$minutes min $seconds s';
}

/// "Standvirtual 15 de 20 · OLX 9 de 20"; null when the run didn't say.
String? requestsText(Map<String, int> requests) {
  if (requests.isEmpty) return null;
  const names = {'standvirtual': 'Standvirtual', 'olx': 'OLX'};
  return [
    for (final MapEntry(:key, :value) in requests.entries)
      '${names[key] ?? key} $value de $requestsPerRunLimit',
  ].join(' · ');
}

/// GitHub bills each job in whole minutes, and a job also spends about
/// half a minute setting up and saving its cache around the collection.
int estimatedMinutes(CollectorRun run) =>
    ((run.duration.inSeconds + 30) / 60).ceil();

/// "18 recolhas este mês, cerca de 54 min de GitHub Actions".
String monthUsageText(List<CollectorRun> runs) {
  final minutes = runs.fold<int>(0, (sum, r) => sum + estimatedMinutes(r));
  return '${runs.length} ${runs.length == 1 ? 'recolha' : 'recolhas'} este '
      'mês, cerca de $minutes min de GitHub Actions';
}
