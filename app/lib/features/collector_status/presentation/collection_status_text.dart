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
  AppLanguage language = AppLanguage.portuguese,
}) {
  switch (token.state) {
    case GithubTokenState.missing:
      return (
        text:
            language.messages.githubTokenIsMissingFromSupabaseVaultCollections,
        warning: true,
      );
    case GithubTokenState.refused:
      return (
        text: language.messages.githubRejectedTokenHTTPCreateNewOneAnd(
          value: (token.httpStatus ?? '?').toString(),
        ),
        warning: true,
      );
    case GithubTokenState.ok:
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
          : days == 1
          ? language.messages.text1DayLeft
          : language.messages.daysLeft(days: (days).toString());
      return (
        text: language.messages.githubTokenValidUntil(
          date: Formatters.date(expires),
          left: left,
          value: days < tokenWarningDays
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
String megabytes(int bytes, {AppLanguage language = AppLanguage.portuguese}) =>
    '${Formatters.decimal(bytes / _megabyte, language: language)} MB';

/// "A base de dados ocupa 42,3 MB de 500 MB (8 %)", red from 80 %.
({String text, bool warning}) databaseUsageText(
  DatabaseUsage usage, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final share = usage.bytes / databaseLimitBytes;
  final warning = share >= databaseWarningShare;
  return (
    text: language.messages.databaseUsesOfMB(
      value: megabytes(usage.bytes, language: language),
      value2: (databaseLimitBytes ~/ _megabyte).toString(),
      percent: Formatters.percent(share * 100, language: language),
      value4: warning
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
  AppLanguage language = AppLanguage.portuguese,
}) {
  if (usage.tables.isEmpty) return null;
  final tables = [
    for (final t in usage.tables)
      '${t.name} ${megabytes(t.bytes, language: language)}',
  ];
  return language.messages.largestTables(value: tables.join(', '));
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
  AppLanguage language = AppLanguage.portuguese,
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
    text: language.messages.todayUTC(
      name: name,
      used: (used).toString(),
      value: used == 1
          ? language.messages.request
          : language.messages.requestsCollectionStatusText,
    ),
    warning: false,
  );
}

/// "OLX · yamaha-mt-07: 2 de 3 páginas, 80 anúncios (9 dos modelos
/// acompanhados) · não lida toda": a search not read in full keeps its gone
/// ads until a run reads it all.
String searchReadText(
  SearchRead s, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final name = '${siteNames[s.site] ?? s.site} · ${s.search}';
  final spans = s.spans;
  if (spans == null) {
    return language.messages.notReadInThisCollection(name: name);
  }
  final pages = language.messages.ofText(
    pages: s.pages.toString(),
    spans: (spans).toString(),
    value: spans == 1 ? language.messages.page : language.messages.pages,
  );
  final ads =
      '${s.ads} ${s.ads == 1 ? language.messages.listing : language.messages.listings}';
  return language.messages.forTrackedModels(
    name: name,
    pages: pages,
    ads: ads,
    followed: s.followed.toString(),
    value: s.inFull ? '' : language.messages.notFullyRead,
  );
}

/// "Correu bem", "Bloqueada" or "Falhou".
String runStatusLabel(
  String status, {
  AppLanguage language = AppLanguage.portuguese,
}) => switch (status) {
  'ok' => language.messages.successful,
  'blocked' => language.messages.blocked,
  _ => language.messages.failed,
};
