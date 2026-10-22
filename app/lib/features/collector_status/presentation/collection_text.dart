import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';

/// The collection starts at minute 40 of these hours, Lisbon time (the
/// pg_cron job 'collect-listings' and collection_due() in
/// supabase/migrations/20261024210000_collection_hours.sql; keep them in
/// step).
const collectionHours = {0, 8, 12, 14, 16, 18, 20};
const _minute = 40;

/// Requests allowed per site and run (FetchPolicy.maxRequestsPerRun).
const requestsPerRunLimit = 20;

/// The next scheduled collection after [now], in UTC.
DateTime nextCollection(DateTime now) {
  final utc = now.toUtc();
  var next = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, _minute);
  while (!next.isAfter(utc) ||
      !collectionHours.contains(next.add(lisbonOffset(next)).hour)) {
    next = next.add(const Duration(hours: 1));
  }
  return next;
}

/// Portugal's offset from UTC at [utc]: an hour of summer time from 01:00
/// UTC on the last Sunday of March to 01:00 UTC on the last Sunday of
/// October (the EU rule), none otherwise.
Duration lisbonOffset(DateTime utc) {
  DateTime lastSunday(int month) {
    final last = DateTime.utc(utc.year, month + 1, 0, 1);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final summer =
      !utc.isBefore(lastSunday(DateTime.march)) &&
      utc.isBefore(lastSunday(DateTime.october));
  return Duration(hours: summer ? 1 : 0);
}

/// "Próxima recolha: hoje às 20:40" (local time). The run itself waits for
/// a free GitHub runner, hence the note.
String nextCollectionText(DateTime now) {
  final next = nextCollection(now).toLocal();
  final when = switch (Formatters.calendarDays(now, next)) {
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
  // A time slightly ahead (clock skew between phone and server) reads as now.
  if (diff.inMinutes < 60) {
    return 'há ${diff.inMinutes < 0 ? 0 : diff.inMinutes} min';
  }
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

/// "3 anúncios novos, 2 preços alterados, 1 anúncio removido, 4 alertas";
/// "Sem anúncios novos nem alterações" when all are zero; null when the run
/// didn't say (older runs, or one that stopped before importing).
String? runCountsText(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  String part(String key, String one, String many) {
    final n = counts[key] ?? 0;
    return n == 1 ? '1 $one' : '$n $many';
  }

  final parts = [
    if ((counts['new'] ?? 0) > 0) part('new', 'anúncio novo', 'anúncios novos'),
    if ((counts['price_changes'] ?? 0) > 0)
      part('price_changes', 'preço alterado', 'preços alterados'),
    if ((counts['removed'] ?? 0) > 0)
      part('removed', 'anúncio removido', 'anúncios removidos'),
    if ((counts['alerts'] ?? 0) > 0) part('alerts', 'alerta', 'alertas'),
  ];
  if (parts.isEmpty) return 'Sem anúncios novos nem alterações';
  return parts.join(', ');
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
