import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../data/collector_runs_repository.dart';
import '../domain/collector_run.dart';
import 'collection_text.dart';
import '../../../core/localization/localizations.dart';

/// The last run's duration and requests, this month's runs and when the
/// next one is due. Runs are readable only when signed in; the next run
/// time is always shown.
class CollectionDetails extends StatefulWidget {
  const CollectionDetails({required this.signedIn, super.key});

  final bool signedIn;

  @override
  State<CollectionDetails> createState() => _CollectionDetailsState();
}

class _CollectionDetailsState extends State<CollectionDetails> {
  Future<List<CollectorRun>>? _monthRuns;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CollectionDetails old) {
    super.didUpdateWidget(old);
    if (old.signedIn != widget.signedIn) _load();
  }

  void _load() {
    final now = DateTime.now().toUtc();
    _monthRuns = widget.signedIn
        ? getIt<CollectorRunsRepository>()
              .getSince(DateTime.utc(now.year, now.month))
              .catchError((_) => const <CollectorRun>[])
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectorRun>>(
      future: _monthRuns,
      builder: (context, snapshot) {
        final lines = <(IconData, String)>[
          (
            Icons.event_outlined,
            nextCollectionText(DateTime.now(), language: context.language),
          ),
        ];
        final runs = snapshot.data ?? const <CollectorRun>[];
        if (runs.isNotEmpty) {
          final last = runs.first;
          lines.insertAll(0, [
            (
              Icons.update,
              context.strings.lastCollectionTook(
                value: agoText(last.finishedAt, language: context.language),
                value2: durationText(last.duration),
              ),
            ),
            if (runCountsText(last.counts, language: context.language)
                case final counts?)
              (Icons.fiber_new_outlined, counts),
            if (requestsText(last.requests, language: context.language)
                case final requests?)
              (Icons.swap_vert, requests),
          ]);
          lines.add((
            Icons.cloud_outlined,
            monthUsageText(runs, language: context.language),
          ));
          if (monthRequestsText(runs, language: context.language)
              case final requests?) {
            lines.add((Icons.swap_vert, requests));
          }
        }
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;

        return Column(
          children: [
            for (final (icon, text) in lines)
              ListTile(
                dense: true,
                leading: Icon(icon, color: muted),
                title: Text(text),
              ),
            if (runs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.strings.githubActionsMinutesAreFreeAndUnlimitedWhile,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        );
      },
    );
  }
}
