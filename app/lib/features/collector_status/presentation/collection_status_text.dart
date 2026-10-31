import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';
import '../domain/database_usage.dart';
import '../domain/github_token.dart';
import '../../../core/localization/localizations.dart';

/// Warn this many days before the GitHub token expires (the database's
/// daily check tells Telegram from the same day).
const tokenWarningDays = 14;

/// What "Estado da recolha" says about the GitHub token, and whether it
/// needs Rafael.
({String text, bool warning}) tokenText(
  GithubToken token,
  DateTime now, {
  AppLanguage language = .portuguese,
}) {
  switch (token.state) {
    case .missing:
      return (text: language.messages.githubTokenMissing, warning: true);
    case .refused:
      return (
        text: language.messages.githubTokenRejected(
          status: (token.httpStatus ?? '?').toString(),
        ),
        warning: true,
      );
    case .ok:
      final expires = token.expiresAt;
      if (expires == null) {
        return (
          text: language.messages.githubTokenValidWithNoExpiryDate,
          warning: false,
        );
      }
      final days = expires.difference(now).inDays;
      final left = days <= 0
          ? language.messages.expiresToday
          : language.messages.daysLeft(days: days);
      return (
        text: language.messages.githubTokenValidUntil(
          date: Formatters.date(expires),
          left: left,
          renewHint: days < tokenWarningDays
              ? language.messages.createNewOneAndReplaceItInSupabase
              : '',
        ),
        warning: days < tokenWarningDays,
      );
  }
}

/// Supabase's free plan: the project turns read-only above this size.
const databaseLimitBytes = 500 * _megabyte;

/// Warn from this share of [databaseLimitBytes].
const databaseWarningShare = 0.8;

const _megabyte = 1024 * 1024;

/// "42,3 MB".
String megabytes(int bytes, {AppLanguage language = .portuguese}) =>
    '${Formatters.decimal(bytes / _megabyte, language: language)} MB';

/// "A base de dados ocupa 42,3 MB de 500 MB (8 %)", red from 80 %.
({String text, bool warning}) databaseUsageText(
  DatabaseUsage usage, {
  AppLanguage language = .portuguese,
}) {
  final share = usage.bytes / databaseLimitBytes;
  final warning = share >= databaseWarningShare;
  return (
    text: language.messages.databaseUsage(
      used: megabytes(usage.bytes, language: language),
      limit: (databaseLimitBytes ~/ _megabyte).toString(),
      percent: Formatters.percent(share * 100, language: language),
      warning: warning
          ? language.messages.nearFreePlanLimitAboveItSupabaseOnly
          : '',
    ),
    warning: warning,
  );
}

/// "Maiores tabelas: listings 30,1 MB, listing_price_history 4,2 MB", or
/// null when there are none.
String? biggestTablesText(
  DatabaseUsage usage, {
  AppLanguage language = .portuguese,
}) {
  if (usage.tables.isEmpty) return null;
  final tables = [
    for (final t in usage.tables)
      '${t.name} ${megabytes(t.bytes, language: language)}',
  ];
  return language.messages.largestTables(tables: tables.join(', '));
}

const siteNames = {'standvirtual': 'Standvirtual', 'olx': 'OLX'};

/// "Standvirtual: 47 pedidos hoje" or "OLX: em pausa até 14:32 de 22/10 (o
/// site recusou pedidos)", from the run [reportedAt]: a run from an earlier
/// UTC day (the fetcher's day) means nothing is used today yet. There is no
/// daily cap, so only a pause is a warning.
({String text, bool warning}) siteBudgetText(
  String site,
  SiteBudget budget, {
  required DateTime reportedAt,
  required DateTime now,
  AppLanguage language = .portuguese,
}) {
  final name = siteNames[site] ?? site;
  final paused = budget.pausedUntil;
  if (paused != null && paused.isAfter(now)) {
    return (
      text: language.messages.pausedUntilOnSiteRefusedRequestsItWill(
        name: name,
        time: Formatters.time(paused),
        date: Formatters.date(paused).substring(0, 5),
      ),
      warning: true,
    );
  }
  final sameDay =
      reportedAt.toUtc().toIso8601String().substring(0, 10) ==
      now.toUtc().toIso8601String().substring(0, 10);
  final used = sameDay ? budget.requestsToday : 0;
  return (
    text: language.messages.requestsToday(name: name, used: used),
    warning: false,
  );
}

/// "OLX · yamaha-mt-07: 2 de 3 páginas, 80 anúncios (9 dos modelos
/// acompanhados) · não lida toda": a search not read in full keeps its gone
/// ads until a run reads it all.
String searchReadText(SearchRead s, {AppLanguage language = .portuguese}) {
  final name = '${siteNames[s.site] ?? s.site} · ${s.search}';
  final spans = s.spans;
  if (spans == null) {
    return language.messages.notReadInThisCollection(name: name);
  }
  final pages = language.messages.pagesReadOf(
    pages: s.pages.toString(),
    spans: spans,
  );
  final ads = language.messages.listingCount(count: s.ads);
  return language.messages.searchReadLine(
    name: name,
    pages: pages,
    ads: ads,
    followed: s.followed.toString(),
    notFullyRead: s.inFull ? '' : language.messages.notFullyRead,
  );
}

/// "Correu bem", "Incompleta", "Bloqueada" or "Falhou".
String runStatusLabel(String status, {AppLanguage language = .portuguese}) =>
    switch (status) {
      'ok' => language.messages.successful,
      'partial' => language.messages.partialRun,
      'blocked' => language.messages.blocked,
      _ => language.messages.failed,
    };

/// The database stops the collector's statements after this long
/// (service_role's statement_timeout); the scoring is the longest one.
const scoringLimit = Duration(seconds: 60);

/// "Pontuações em 4,2 s"; a warning past half of [scoringLimit], before
/// a growing catalogue makes the scoring fail.
({String text, bool warning}) scoringText(
  Duration time, {
  AppLanguage language = .portuguese,
}) {
  final seconds = Formatters.decimal(
    time.inMilliseconds / 1000,
    language: language,
  );
  final warning = time * 2 > scoringLimit;
  return (
    text: warning
        ? language.messages.scoringTookTooLong(
            seconds: seconds,
            limit: scoringLimit.inSeconds.toString(),
          )
        : language.messages.scoringTime(seconds: seconds),
    warning: warning,
  );
}

/// What made a run fail, from one of its problem lines (refresh.dart's
/// wording, after the site).
String failureCause(String problem, {AppLanguage language = .portuguese}) {
  final line = _withoutSite(problem).line;
  final messages = language.messages;
  return switch (line) {
    _ when line.startsWith('Stopped, the site pushed back') =>
      messages.failureSiteRefused,
    _ when line.startsWith('Not fetched: ') =>
      messages.failurePausedOrNotAllowed,
    _ when line.startsWith('Failed: ') => messages.failureNoResponse,
    _ when line.startsWith('Database error: ') => messages.failureDatabase,
    _
        when line.startsWith('Read issue: ') ||
            line.startsWith('Cannot read the saved pages: ') ||
            line.startsWith('Not a search results page: ') =>
      messages.failureUnreadablePages,
    _ => messages.failureOther,
  };
}

/// `olx: Failed: …` -> (site: olx, line: Failed: …); no site when the
/// line names none (an error after the sites, or before them).
({String? site, String line}) _withoutSite(String problem) {
  final match = RegExp(r'^(\w+): (.*)$').firstMatch(problem);
  if (match == null || !siteNames.containsKey(match.group(1))) {
    return (site: null, line: problem);
  }
  return (site: match.group(1), line: match.group(2)!);
}

/// The runs in [runs] that were not ok, by site and cause, most frequent
/// first: "OLX · Sem resposta ou erro do site (tempo esgotado, HTTP 5xx):
/// 3 recolhas, a última a 26/10 às 14:02". A run counts once per site and
/// cause; one without problem lines is "Outro erro".
List<String> failureHistoryText(
  List<CollectorRun> runs, {
  AppLanguage language = .portuguese,
}) {
  final groups = <String, ({int runs, DateTime last})>{};
  for (final run in runs.where((r) => r.status != 'ok')) {
    final keys = {
      for (final problem in run.problems)
        [
          if (_withoutSite(problem).site case final site?) siteNames[site],
          failureCause(problem, language: language),
        ].join(' · '),
    };
    if (keys.isEmpty) keys.add(language.messages.failureOther);
    for (final key in keys) {
      final seen = groups[key];
      groups[key] = (
        runs: (seen?.runs ?? 0) + 1,
        last: seen == null || run.startedAt.isAfter(seen.last)
            ? run.startedAt
            : seen.last,
      );
    }
  }
  final sorted = groups.entries.toList()
    ..sort(
      (a, b) => b.value.runs != a.value.runs
          ? b.value.runs.compareTo(a.value.runs)
          : b.value.last.compareTo(a.value.last),
    );
  return [
    for (final MapEntry(:key, :value) in sorted)
      language.messages.failureHistoryLine(
        cause: key,
        count: value.runs,
        date: Formatters.date(value.last).substring(0, 5),
        time: Formatters.time(value.last),
      ),
  ];
}

/// "4 de 180 recolhas não correram bem", over [runs] (at least one).
String failureShareText(
  List<CollectorRun> runs, {
  AppLanguage language = .portuguese,
}) {
  final failed = runs.where((r) => r.status != 'ok').length;
  return failed == 0
      ? language.messages.failureShareNone(count: runs.length)
      : language.messages.failureShare(failed: failed, total: runs.length);
}
