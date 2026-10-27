import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';
import '../domain/database_usage.dart';
import '../domain/github_token.dart';

/// Warn this many days before the GitHub token expires (the database's
/// daily check tells Telegram from the same day).
const tokenWarningDays = 14;

/// What "Estado da recolha" says about the GitHub token, and whether it
/// needs Rafael.
({String text, bool warning}) tokenText(GithubToken token, DateTime now) {
  switch (token.state) {
    case GithubTokenState.missing:
      return (
        text:
            'Falta o token do GitHub no Vault do Supabase: as recolhas não '
            'começam sozinhas (docs/hosting.md).',
        warning: true,
      );
    case GithubTokenState.refused:
      return (
        text:
            'O GitHub recusou o token (HTTP ${token.httpStatus ?? '?'}). Crie '
            'um novo e substitua-o no Vault do Supabase.',
        warning: true,
      );
    case GithubTokenState.ok:
      final expires = token.expiresAt;
      if (expires == null) {
        return (
          text: 'Token do GitHub válido, sem data de fim.',
          warning: false,
        );
      }
      final days = expires.difference(now).inDays;
      final left = days <= 0
          ? 'termina hoje'
          : days == 1
          ? 'falta 1 dia'
          : 'faltam $days dias';
      return (
        text:
            'Token do GitHub válido até ${Formatters.date(expires)} ($left).'
            '${days < tokenWarningDays ? ' Crie um novo e substitua-o no '
                      'Vault do Supabase.' : ''}',
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
String megabytes(int bytes) =>
    '${(bytes / _megabyte).toStringAsFixed(1).replaceAll('.', ',')} MB';

/// "A base de dados ocupa 42,3 MB de 500 MB (8 %)", red from 80 %.
({String text, bool warning}) databaseUsageText(DatabaseUsage usage) {
  final share = usage.bytes / databaseLimitBytes;
  final warning = share >= databaseWarningShare;
  return (
    text:
        'A base de dados ocupa ${megabytes(usage.bytes)} de '
        '${databaseLimitBytes ~/ _megabyte} MB '
        '(${Formatters.percent(share * 100)}).'
        '${warning ? ' Perto do limite do plano gratuito: acima dele o '
                  'Supabase só deixa ler.' : ''}',
    warning: warning,
  );
}

/// "Maiores tabelas: listings 30,1 MB, listing_price_history 4,2 MB", or
/// null when there are none.
String? biggestTablesText(DatabaseUsage usage) {
  if (usage.tables.isEmpty) return null;
  final tables = [
    for (final t in usage.tables) '${t.name} ${megabytes(t.bytes)}',
  ];
  return 'Maiores tabelas: ${tables.join(', ')}';
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
}) {
  final name = siteNames[site] ?? site;
  final paused = budget.pausedUntil;
  if (paused != null && paused.isAfter(now)) {
    return (
      text:
          '$name: em pausa até ${Formatters.time(paused)} de '
          '${Formatters.date(paused).substring(0, 5)} (o site recusou '
          'pedidos; volta a tentar sozinho)',
      warning: true,
    );
  }
  final sameDay =
      reportedAt.toUtc().toIso8601String().substring(0, 10) ==
      now.toUtc().toIso8601String().substring(0, 10);
  final used = sameDay ? budget.requestsToday : 0;
  return (
    text: '$name: $used ${used == 1 ? 'pedido' : 'pedidos'} hoje (UTC)',
    warning: false,
  );
}

/// "OLX · yamaha-mt-07: 2 de 3 páginas, 80 anúncios (9 dos modelos
/// acompanhados) · não lida toda": a search not read in full keeps its gone
/// ads until a run reads it all.
String searchReadText(SearchRead s) {
  final name = '${siteNames[s.site] ?? s.site} · ${s.search}';
  final spans = s.spans;
  if (spans == null) return '$name: não lida nesta recolha';
  final pages = '${s.pages} de $spans ${spans == 1 ? 'página' : 'páginas'}';
  final ads = '${s.ads} ${s.ads == 1 ? 'anúncio' : 'anúncios'}';
  return '$name: $pages, $ads (${s.followed} dos modelos acompanhados)'
      '${s.inFull ? '' : ' · não lida toda'}';
}

/// "Correu bem", "Incompleta", "Bloqueada" or "Falhou".
String runStatusLabel(String status) => switch (status) {
  'ok' => 'Correu bem',
  'partial' => 'Incompleta',
  'blocked' => 'Bloqueada',
  _ => 'Falhou',
};

/// The database stops the collector's statements after this long
/// (service_role's statement_timeout); the scoring is the longest one.
const scoringLimit = Duration(seconds: 60);

/// "Pontuações em 4,2 s"; a warning past half of [scoringLimit], before
/// a growing catalogue makes the scoring fail.
({String text, bool warning}) scoringText(Duration time) {
  final seconds = (time.inMilliseconds / 1000)
      .toStringAsFixed(1)
      .replaceAll('.', ',');
  final warning = time * 2 > scoringLimit;
  return (
    text: warning
        ? 'As pontuações demoraram $seconds s, mais de metade do limite de '
              '${scoringLimit.inSeconds} s da base de dados.'
        : 'Pontuações em $seconds s',
    warning: warning,
  );
}

/// What made a run fail, from one of its problem lines (refresh.dart's
/// wording, after the site).
String failureCause(String problem) {
  final line = _withoutSite(problem).line;
  return switch (line) {
    _ when line.startsWith('Stopped, the site pushed back') =>
      'O site recusou os pedidos',
    _ when line.startsWith('Not fetched: ') =>
      'Em pausa ou pedido não permitido',
    _ when line.startsWith('Failed: ') =>
      'Sem resposta ou erro do site (tempo esgotado, HTTP 5xx)',
    _ when line.startsWith('Database error: ') => 'Erro da base de dados',
    _
        when line.startsWith('Read issue: ') ||
            line.startsWith('Cannot read the saved pages: ') ||
            line.startsWith('Not a search results page: ') =>
      'Páginas que não foi possível ler',
    _ => 'Outro erro',
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
List<String> failureHistoryText(List<CollectorRun> runs) {
  final groups = <String, ({int runs, DateTime last})>{};
  for (final run in runs.where((r) => r.status != 'ok')) {
    final keys = {
      for (final problem in run.problems)
        [
          if (_withoutSite(problem).site case final site?) siteNames[site],
          failureCause(problem),
        ].join(' · '),
    };
    if (keys.isEmpty) keys.add('Outro erro');
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
      '$key: ${value.runs} ${value.runs == 1 ? 'recolha' : 'recolhas'}, '
          '${value.runs == 1 ? 'a' : 'a última a'} '
          '${Formatters.date(value.last).substring(0, 5)} às '
          '${Formatters.time(value.last)}',
  ];
}

/// "4 de 180 recolhas não correram bem", over [runs] (at least one).
String failureShareText(List<CollectorRun> runs) {
  final failed = runs.where((r) => r.status != 'ok').length;
  if (failed == 0) {
    return runs.length == 1
        ? 'A recolha correu bem'
        : 'As ${runs.length} recolhas correram todas bem';
  }
  return '$failed de ${runs.length} '
      '${runs.length == 1 ? 'recolha' : 'recolhas'} '
      '${failed == 1 ? 'não correu' : 'não correram'} bem';
}
