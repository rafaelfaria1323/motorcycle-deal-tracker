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
import '../../../core/localization/localizations.dart';

/// "Estado da recolha" (admins, from Mais): whether the GitHub token still
/// starts the runs, how much database space is used, each site's requests
/// today and pause, the requests of each of the last 7 days, and the last
/// runs with what went wrong and a link to
/// each one on GitHub.
class CollectionStatusPage extends StatefulWidget {
  const CollectionStatusPage({super.key});

  @override
  State<CollectionStatusPage> createState() => _CollectionStatusPageState();
}

class _CollectionStatusPageState extends State<CollectionStatusPage> {
  static const _runs = 20;

  late Future<List<CollectorRun>> _recent;
  late Future<List<CollectorRun>> _week;
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
    _week = repository
        .getSince(DateTime.now().subtract(const Duration(days: 7)))
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
    await (_recent, _week, _token, _usage).wait;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.collectionStatus),
      ),
      body: FutureBuilder<List<CollectorRun>>(
        future: _recent,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: context.strings.couldNotLoadCollectionRuns,
              actionLabel: context.strings.retry,
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
                  title: context.strings.automaticStart,
                  footnote: context
                      .strings
                      .supabaseUsesThisTokenToStartCollectionsAnd,
                  children: [_TokenLine(token: _token, now: now)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.database,
                  footnote:
                      context.strings.freeSupabasePlanAllows500MBAboveThat,
                  children: [_UsageLines(usage: _usage)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.sites,
                  footnote: context
                      .strings
                      .noRequestLimitsEachCollectionReadsEverySearch,
                  children: [
                    if (latestWithSites == null)
                      BulletLine(context.strings.noDataYetItWillAppearAfterNext)
                    else
                      for (final MapEntry(:key, :value)
                          in latestWithSites.sites.entries)
                        _WarningLine(
                          siteBudgetText(
                            key,
                            value,
                            reportedAt: latestWithSites.finishedAt,
                            now: now,
                            language: context.language,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.searches,
                  footnote:
                      context.strings.fromLastCollectionPagesReadForEachSearch,
                  children: [
                    if (latestWithSearches == null)
                      BulletLine(context.strings.noDataYetItWillAppearAfterNext)
                    else
                      for (final search in latestWithSearches.searches)
                        BulletLine(
                          searchReadText(search, language: context.language),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.requestsPerDay,
                  footnote: context.strings.last7DaysAddingTogetherEachDayS,
                  children: [_DailyRequests(runs: _week, now: now)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.recentCollections,
                  footnote: context.strings.tapCollectionToSeeItsLogOnGitHub,
                  children: [
                    if (runs.isEmpty)
                      BulletLine(context.strings.noCollectionRunsRecordedYet),
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
          return BulletLine(context.strings.checkingGitHubToken);
        }
        final token = snapshot.data;
        if (token == null) {
          return BulletLine(context.strings.couldNotCheckGitHubToken);
        }
        return _WarningLine(tokenText(token, now, language: context.language));
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
          return BulletLine(context.strings.countingRequests);
        }
        final days = dailyRequestsText(
          snapshot.data ?? const [],
          now,
          language: context.language,
        );
        if (days.isEmpty) {
          return BulletLine(context.strings.noRequestsRecordedYet);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final day in days) BulletLine(day)],
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
          return BulletLine(context.strings.measuringDatabase);
        }
        final usage = snapshot.data;
        if (usage == null) {
          return BulletLine(context.strings.couldNotMeasureDatabase);
        }
        final tables = biggestTablesText(usage, language: context.language);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WarningLine(databaseUsageText(usage, language: context.language)),
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
    final ok = run.status == 'ok';
    final url = run.runUrl;
    final details = [
      context.strings.took(value: durationText(run.duration)),
      ?requestsText(run.requests, language: context.language),
      ?runCountsText(run.counts, language: context.language),
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle_outline : Icons.error_outline,
        color: ok
            ? AppColors.of(context).positive
            : AppColors.of(context).negative,
      ),
      title: Text(
        context.strings.at(
          value: runStatusLabel(run.status, language: context.language),
          date: Formatters.date(run.startedAt),
          time: Formatters.time(run.startedAt),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details.join(' · ')),
          for (final problem in run.problems)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                problem,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.of(context).negative,
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
