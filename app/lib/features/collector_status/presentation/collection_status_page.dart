import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/di/injection.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/widgets/page_back_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/state_message.dart';
import '../data/collector_runs_repository.dart';
import '../data/database_usage_repository.dart';
import '../data/github_token_repository.dart';
import '../domain/collector_run.dart';
import '../domain/database_usage.dart';
import '../domain/github_token.dart';
import 'collection_status_text.dart';
import 'collection_text.dart';

/// "Estado da recolha" (admins, from Mais): whether the GitHub token still
/// starts the runs, how much database space is used, each site's requests
/// today and pause, the requests of each of the last 7 days, the last 30
/// days' failures by site and cause, and the last runs with what went
/// wrong, how long the scores took and a link to each one on GitHub.
class CollectionStatusPage extends StatefulWidget {
  const CollectionStatusPage({super.key});

  @override
  State<CollectionStatusPage> createState() => _CollectionStatusPageState();
}

class _CollectionStatusPageState extends State<CollectionStatusPage> {
  static const _runs = 20;

  late Future<List<CollectorRun>> _recent;
  late Future<List<CollectorRun>> _month;
  late Future<GithubToken?> _token;
  late Future<DatabaseUsage?> _usage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = getIt<CollectorRunsRepository>();
    _recent = repository.getRecent(_runs);
    _month = repository
        .getSince(DateTime.now().subtract(const Duration(days: 30)))
        .catchError((Object _) => const <CollectorRun>[]);
    _token = getIt<GithubTokenRepository>().check().then<GithubToken?>(
      (t) => t,
      onError: (Object _) => null,
    );
    _usage = getIt<DatabaseUsageRepository>().get().then<DatabaseUsage?>(
      (u) => u,
      onError: (Object _) => null,
    );
  }

  Future<void> _reload() async {
    setState(_load);
    await (_recent, _month, _token, _usage).wait;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('Estado da recolha'),
      ),
      body: FutureBuilder<List<CollectorRun>>(
        future: _recent,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: 'Não foi possível carregar as recolhas',
              actionLabel: 'Tentar novamente',
              onAction: () => unawaited(_reload()),
            );
          }
          final runs = snapshot.data;
          if (runs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final latestWithSites = runs
              .where((r) => r.sites.isNotEmpty)
              .firstOrNull;
          final latestWithSearches = runs
              .where((r) => r.searches.isNotEmpty)
              .firstOrNull;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Início automático',
                  footnote:
                      'O Supabase usa este token para iniciar as recolhas e o '
                      'resumo semanal. Avisa também no Telegram 14 dias antes '
                      'de terminar.',
                  children: [_TokenLine(token: _token, now: now)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Base de dados',
                  footnote:
                      'O plano gratuito do Supabase permite 500 MB; acima '
                      'disso o projeto passa a só leitura.',
                  children: [_UsageLines(usage: _usage)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Sites',
                  footnote:
                      'Sem limite de pedidos: cada recolha lê todas as '
                      'páginas das pesquisas e os anúncios por ler, um pedido '
                      'de cada vez, 6 a 10 s entre eles, até 30 min por site. '
                      'Se um site recusar pedidos, fica em pausa 24 h.',
                  children: [
                    if (latestWithSites == null)
                      const BulletLine(
                        'Ainda sem dados: aparecem depois da próxima recolha.',
                      )
                    else
                      for (final MapEntry(:key, :value)
                          in latestWithSites.sites.entries)
                        _WarningLine(
                          siteBudgetText(
                            key,
                            value,
                            reportedAt: latestWithSites.finishedAt,
                            now: now,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Pesquisas',
                  footnote:
                      'Da última recolha: páginas lidas de cada pesquisa e '
                      'anúncios encontrados. Só uma pesquisa lida toda marca '
                      'como retirados os anúncios que já não aparecem.',
                  children: [
                    if (latestWithSearches == null)
                      const BulletLine(
                        'Ainda sem dados: aparecem depois da próxima recolha.',
                      )
                    else
                      for (final search in latestWithSearches.searches)
                        BulletLine(searchReadText(search)),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Pedidos por dia',
                  footnote:
                      'Os últimos 7 dias, somando as recolhas de cada '
                      'dia.',
                  children: [_DailyRequests(runs: _month, now: now)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Falhas nos últimos 30 dias',
                  footnote:
                      'Por site e causa. Uma recolha incompleta perdeu uma '
                      'pesquisa ou um site por uma falha passageira; a '
                      'seguinte volta a ler. O aviso no telemóvel só chega '
                      'se o mesmo site falhar em duas recolhas seguidas.',
                  children: [_FailureHistory(runs: _month)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Últimas recolhas',
                  footnote: 'Toque numa recolha para ver o registo no GitHub.',
                  children: [
                    if (runs.isEmpty)
                      const BulletLine('Ainda nenhuma recolha registada.'),
                    for (final run in runs) _RunTile(run: run),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TokenLine extends StatelessWidget {
  const _TokenLine({required this.token, required this.now});

  final Future<GithubToken?> token;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GithubToken?>(
      future: token,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BulletLine('A verificar o token do GitHub…');
        }
        final token = snapshot.data;
        if (token == null) {
          return const BulletLine(
            'Não foi possível verificar o token do GitHub.',
          );
        }
        return _WarningLine(tokenText(token, now));
      },
    );
  }
}

class _DailyRequests extends StatelessWidget {
  const _DailyRequests({required this.runs, required this.now});

  final Future<List<CollectorRun>> runs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: runs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BulletLine('A contar os pedidos…');
        }
        final week = now.subtract(const Duration(days: 7));
        final days = dailyRequestsText([
          for (final run in snapshot.data ?? const <CollectorRun>[])
            if (run.startedAt.isAfter(week)) run,
        ], now);
        if (days.isEmpty) {
          return const BulletLine('Ainda sem pedidos registados.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final day in days) BulletLine(day)],
        );
      },
    );
  }
}

class _FailureHistory extends StatelessWidget {
  const _FailureHistory({required this.runs});

  final Future<List<CollectorRun>> runs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: runs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BulletLine('A contar as falhas…');
        }
        final runs = snapshot.data ?? const <CollectorRun>[];
        if (runs.isEmpty) {
          return const BulletLine('Ainda nenhuma recolha registada.');
        }
        final causes = failureHistoryText(runs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BulletLine(
              failureShareText(runs),
              icon: causes.isEmpty ? Icons.check_circle_outline : null,
            ),
            for (final cause in causes) BulletLine(cause),
          ],
        );
      },
    );
  }
}

class _UsageLines extends StatelessWidget {
  const _UsageLines({required this.usage});

  final Future<DatabaseUsage?> usage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseUsage?>(
      future: usage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BulletLine('A medir a base de dados…');
        }
        final usage = snapshot.data;
        if (usage == null) {
          return const BulletLine('Não foi possível medir a base de dados.');
        }
        final tables = biggestTablesText(usage);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WarningLine(databaseUsageText(usage)),
            if (tables != null) BulletLine(tables),
          ],
        );
      },
    );
  }
}

/// A line that turns red with a warning icon when it needs Rafael.
class _WarningLine extends StatelessWidget {
  const _WarningLine(this.line);

  final ({String text, bool warning}) line;

  @override
  Widget build(BuildContext context) {
    if (!line.warning) {
      return BulletLine(line.text, icon: Icons.check_circle_outline);
    }
    final negative = AppColors.of(context).negative;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line.text, style: TextStyle(color: negative)),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final CollectorRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final url = run.runUrl;
    final scoring = switch (run.scoringTime) {
      final time? => scoringText(time),
      null => null,
    };
    final details = [
      'Demorou ${durationText(run.duration)}',
      if (scoring != null && !scoring.warning) scoring.text,
      ?requestsText(run.requests),
      ?runCountsText(run.counts),
    ];
    final warnings = [
      if (scoring != null && scoring.warning) scoring.text,
      ...run.problems,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: switch (run.status) {
        'ok' => Icon(Icons.check_circle_outline, color: colors.positive),
        'partial' => Icon(Icons.warning_amber_rounded, color: colors.negative),
        _ => Icon(Icons.error_outline, color: colors.negative),
      },
      title: Text(
        '${runStatusLabel(run.status)} · ${Formatters.date(run.startedAt)} às '
        '${Formatters.time(run.startedAt)}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details.join(' · ')),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                warning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.negative,
                ),
              ),
            ),
        ],
      ),
      trailing: url == null ? null : const Icon(Icons.open_in_new, size: 18),
      onTap: url == null
          ? null
          : () => unawaited(
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
    );
  }
}
