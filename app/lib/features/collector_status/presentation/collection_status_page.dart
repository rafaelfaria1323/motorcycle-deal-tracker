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
import '../data/source_quality_repository.dart';
import '../domain/collector_run.dart';
import '../domain/database_usage.dart';
import '../domain/github_token.dart';
import '../domain/source_quality.dart';
import 'collection_status_text.dart';
import 'collection_text.dart';
import 'data_quality_details.dart';
import '../../../core/localization/localizations.dart';

/// "Estado da recolha" (admins, from Mais): whether the GitHub token still
/// starts the runs, how much database space is used, each site's requests
/// today and pause, the searches read, the requests of each of the last 7
/// days, this month's runs and GitHub minutes, the last 30 days' failures
/// by site and cause, each site's data quality, and the last runs with
/// what went wrong, how long the scores took and a link to each one on
/// GitHub.
class const CollectionStatusPage({super.key}) extends StatefulWidget {
  @override
  State<CollectionStatusPage> createState() => _CollectionStatusPageState();
}

class _CollectionStatusPageState extends State<CollectionStatusPage> {
  static const _runs = 20;

  late Future<List<CollectorRun>> _recent;
  late Future<List<CollectorRun>> _month;
  late Future<List<CollectorRun>> _thisMonth;
  late Future<GithubToken?> _token;
  late Future<DatabaseUsage?> _usage;
  late Future<List<SourceQuality>?> _quality;

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
    final now = DateTime.now().toUtc();
    _thisMonth = repository
        .getSince(DateTime.utc(now.year, now.month))
        .catchError((Object _) => const <CollectorRun>[]);
    _token = getIt<GithubTokenRepository>().check().then<GithubToken?>(
      (t) => t,
      onError: (Object _) => null,
    );
    _usage = getIt<DatabaseUsageRepository>().get().then<DatabaseUsage?>(
      (u) => u,
      onError: (Object _) => null,
    );
    _quality = getIt<SourceQualityRepository>()
        .getAll()
        .then<List<SourceQuality>?>((q) => q, onError: (Object _) => null);
  }

  Future<void> _reload() async {
    setState(_load);
    await (_recent, _month, _thisMonth, _token, _usage, _quality).wait;
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
                  footnote: context.strings.githubTokenExplanation,
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
                  footnote: context.strings.requestLimitsNote,
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
                  footnote: context.strings.searchesReadIntro,
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
                  children: [_DailyRequests(runs: _month, now: now)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.thisMonth,
                  footnote: context.strings.githubActionsMinutesNote,
                  children: [_MonthLines(runs: _thisMonth)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.failuresLast30Days,
                  footnote: context.strings.failuresLast30DaysFootnote,
                  children: [_FailureHistory(runs: _month)],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: context.strings.dataQuality,
                  children: [DataQualityDetails(quality: _quality)],
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

class const _TokenLine({
  required final Future<GithubToken?> token,
  required final DateTime now,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GithubToken?>(
      future: token,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
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

class const _DailyRequests({
  required final Future<List<CollectorRun>> runs,
  required final DateTime now,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: runs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return BulletLine(context.strings.countingRequests);
        }
        final week = now.subtract(const Duration(days: 7));
        final days = dailyRequestsText(
          [
            for (final run in snapshot.data ?? const <CollectorRun>[])
              if (run.startedAt.isAfter(week)) run,
          ],
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

/// This month's runs and their GitHub minutes, and each site's requests.
class const _MonthLines({required final Future<List<CollectorRun>> runs})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: runs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return BulletLine(context.strings.countingRequests);
        }
        final runs = snapshot.data ?? const <CollectorRun>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BulletLine(monthUsageText(runs, language: context.language)),
            if (monthRequestsText(runs, language: context.language)
                case final requests?)
              BulletLine(requests),
          ],
        );
      },
    );
  }
}

class const _FailureHistory({required final Future<List<CollectorRun>> runs})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: runs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return BulletLine(context.strings.countingFailures);
        }
        final runs = snapshot.data ?? const <CollectorRun>[];
        if (runs.isEmpty) {
          return BulletLine(context.strings.noCollectionRunsRecordedYet);
        }
        final causes = failureHistoryText(runs, language: context.language);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BulletLine(
              failureShareText(runs, language: context.language),
              icon: causes.isEmpty ? Icons.check_circle_outline : null,
            ),
            for (final cause in causes) BulletLine(cause),
          ],
        );
      },
    );
  }
}

class const _UsageLines({required final Future<DatabaseUsage?> usage})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseUsage?>(
      future: usage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
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
class const _WarningLine(final ({String text, bool warning}) line)
    extends StatelessWidget {
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

class const _RunTile({required final CollectorRun run})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final url = run.runUrl;
    final scoring = switch (run.scoringTime) {
      final time? => scoringText(time, language: context.language),
      null => null,
    };
    final details = [
      context.strings.took(duration: durationText(run.duration)),
      if (scoring != null && !scoring.warning) scoring.text,
      ?requestsText(run.requests, language: context.language),
      ?runCountsText(run.counts, language: context.language),
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
        context.strings.runLine(
          status: runStatusLabel(run.status, language: context.language),
          date: Formatters.date(run.startedAt),
          time: Formatters.time(run.startedAt),
        ),
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
              launchUrl(Uri.parse(url), mode: .externalApplication),
            ),
    );
  }
}
