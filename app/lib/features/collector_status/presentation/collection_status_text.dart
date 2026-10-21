import '../../../core/formatting/formatters.dart';
import '../domain/collector_run.dart';
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

const siteNames = {'standvirtual': 'Standvirtual', 'olx': 'OLX'};

/// "Standvirtual: 47 de 120 pedidos hoje" or "OLX: em pausa até 14:32 de
/// 22/10 (o site recusou pedidos)", from the run [reportedAt]: a run from
/// an earlier UTC day (the budget's day) means nothing is used today yet.
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
    text: '$name: $used de ${budget.dailyLimit} pedidos hoje',
    warning: used >= budget.dailyLimit,
  );
}

/// "Correu bem", "Bloqueada" or "Falhou".
String runStatusLabel(String status) => switch (status) {
  'ok' => 'Correu bem',
  'blocked' => 'Bloqueada',
  _ => 'Falhou',
};
