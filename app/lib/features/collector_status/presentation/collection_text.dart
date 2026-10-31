import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';
import 'collection_status_text.dart';
import '../../../core/localization/localizations.dart';

/// The collection starts on the hour at these hours, Lisbon time (the
/// pg_cron job 'collect-listings' and collection_due() in
/// supabase/migrations/20261027210000_collection_hours_every_two.sql; keep
/// them in step).
const collectionHours = {0, 8, 10, 12, 14, 16, 18, 20, 22};

/// The next scheduled collection after [now], in UTC.
DateTime nextCollection(DateTime now) {
  final utc = now.toUtc();
  var next = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
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

/// "Próxima recolha: hoje às 20:00" (local time). The run itself waits for
/// a free GitHub runner, hence the note.
String nextCollectionText(DateTime now, {AppLanguage language = .portuguese}) {
  final next = nextCollection(now).toLocal();
  final when = switch (Formatters.calendarDays(now, next)) {
    0 => language.messages.today,
    1 => language.messages.tomorrow,
    _ => Formatters.date(next),
  };
  final time =
      '${next.hour.toString().padLeft(2, '0')}:'
      '${next.minute.toString().padLeft(2, '0')}';
  return language.messages.nextCollection(day: when, time: time);
}

/// Mais' one line on the collection (F.5): how the last run went and when
/// the next is due. Anonymous sessions can't read the runs
/// (`collector_runs`), so [run] is null for them and only the next run is
/// said. The runs themselves and the data quality are the admins'
/// ("Estado da recolha").
({CollectorHealth health, String title, String? subtitle}) collectionLine(
  CollectorRun? run,
  DateTime now, {
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  final next = nextCollectionText(now, language: language);
  final health = collectorHealth(run, now);
  if (run == null) return (health: health, title: next, subtitle: null);
  final ago = agoText(run.finishedAt, now: now, language: language);
  return switch (health) {
    .unknown || .ok => (
      health: health,
      title: messages.lastCollection(ago: ago),
      subtitle: next,
    ),
    .stale => (
      health: health,
      title: messages.noRecentUpdates,
      subtitle: '${messages.bannerStale(ago: ago)}\n$next',
    ),
    // The site's pause decides when it is read again, not the schedule.
    .blocked => (
      health: health,
      title: messages.collectionBlockedBySite,
      subtitle: messages.bannerSiteBlocked(ago: ago),
    ),
    .failed => (
      health: health,
      title: messages.lastCollectionFailed,
      subtitle: '${capitalize(ago)} · $next',
    ),
  };
}

/// "há 3 h" (or minutes, or days).
String agoText(
  DateTime time, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) {
  final diff = (now ?? DateTime.now()).difference(time);
  // A time slightly ahead (clock skew between phone and server) reads as now.
  if (diff.inMinutes < 60) {
    return language.messages.minutesAgo(
      minutes: (diff.inMinutes < 0 ? 0 : diff.inMinutes).toString(),
    );
  }
  if (diff.inHours < 48) {
    return language.messages.hAgo(inHours: diff.inHours.toString());
  }
  return language.messages.daysAgo(days: diff.inDays.toString());
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

/// "Pedidos: Standvirtual 15 · OLX 9" (the sites have no request cap, so
/// these are the figures to watch); null when the run didn't say.
String? requestsText(
  Map<String, int> requests, {
  AppLanguage language = .portuguese,
}) => requests.isEmpty
    ? null
    : language.messages.requestsPerSite(sites: _perSite(requests));

String _perSite(Map<String, int> requests) => [
  for (final MapEntry(:key, :value) in requests.entries)
    '${siteNames[key] ?? key} $value',
].join(' · ');

/// "Pedidos este mês: Standvirtual 420 (15 por recolha) · OLX 280 (10 por
/// recolha)": each site's total over [runs] and its average over the runs
/// that counted it; null when none did (older runs).
String? monthRequestsText(
  List<CollectorRun> runs, {
  AppLanguage language = .portuguese,
}) {
  final totals = <String, int>{};
  final counted = <String, int>{};
  for (final run in runs) {
    for (final MapEntry(:key, :value) in run.requests.entries) {
      totals[key] = (totals[key] ?? 0) + value;
      counted[key] = (counted[key] ?? 0) + 1;
    }
  }
  if (totals.isEmpty) return null;
  return language.messages.requestsThisMonth(
    sites: [
      for (final MapEntry(:key, :value) in totals.entries)
        language.messages.requestsPerCollection(
          site: siteNames[key] ?? key,
          total: (value).toString(),
          perRun: (value / counted[key]!).round().toString(),
        ),
    ].join(' · '),
  );
}

/// "Hoje: Standvirtual 105 · OLX 70", "Ontem: …", "20/10: …": each local
/// day's requests per site over [runs] (by when the run started), newest
/// day first. Days without counted runs are left out.
List<String> dailyRequestsText(
  List<CollectorRun> runs,
  DateTime now, {
  AppLanguage language = .portuguese,
}) {
  final days = <DateTime, Map<String, int>>{};
  for (final run in runs) {
    final start = run.startedAt.toLocal();
    final sites = days.putIfAbsent(
      DateTime(start.year, start.month, start.day),
      () => {},
    );
    for (final MapEntry(:key, :value) in run.requests.entries) {
      sites[key] = (sites[key] ?? 0) + value;
    }
  }
  final sorted = days.keys.where((d) => days[d]!.isNotEmpty).toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final day in sorted)
      '${switch (Formatters.calendarDays(day, now)) {
        0 => language.messages.todayCollectionText,
        1 => language.messages.yesterdayCollectionText,
        _ => Formatters.date(day).substring(0, 5),
      }}: ${_perSite(days[day]!)}',
  ];
}

/// "3 anúncios novos, 2 preços alterados, 1 anúncio removido, 4 alertas";
/// "Sem anúncios novos nem alterações" when all are zero; null when the run
/// didn't say (older runs, or one that stopped before importing).
String? runCountsText(
  Map<String, int> counts, {
  AppLanguage language = .portuguese,
}) {
  if (counts.isEmpty) return null;
  final messages = language.messages;
  final parts = [
    if (counts['new'] case final n? when n > 0)
      messages.newListingCount(count: n),
    if (counts['price_changes'] case final n? when n > 0)
      messages.priceChangeCount(count: n),
    if (counts['removed'] case final n? when n > 0)
      messages.removedListingCount(count: n),
    if (counts['alerts'] case final n? when n > 0)
      messages.alertCount(count: n),
  ];
  if (parts.isEmpty) return language.messages.noNewListingsOrChanges;
  return parts.join(', ');
}

/// GitHub bills each job in whole minutes, and a job also spends about
/// half a minute setting up and saving its cache around the collection.
int estimatedMinutes(CollectorRun run) =>
    ((run.duration.inSeconds + 30) / 60).ceil();

/// "18 recolhas este mês, cerca de 54 min de GitHub Actions".
String monthUsageText(
  List<CollectorRun> runs, {
  AppLanguage language = .portuguese,
}) {
  final minutes = runs.fold<int>(0, (sum, r) => sum + estimatedMinutes(r));
  return language.messages.runsThisMonth(
    count: runs.length,
    minutes: (minutes).toString(),
  );
}
