import 'dart:io';

import 'package:collector/collector.dart';

/// Records one scheduled run in `collector_runs` (with its problems, each
/// search's pages and ads, each site's requests today and pause, how long
/// the scoring took and the GitHub run's address), drops rows older than
/// 90 days and tells the admins' devices (Web Push) when the collection
/// breaks or recovers (runHealthMessage: a change from the previous runs
/// only; a partial run only when its site failed in the run before too).
/// In GitHub Actions the status goes to the step's outputs (`status`), so
/// a partial run doesn't fail the job.
/// What the run did comes from the report refresh.dart wrote
/// (`--report`, N.57); the log is read only when there is none (the run
/// stopped before its first site ended, or never started).
/// Usage: `report_run.dart <exit-code> <started-at> <log-file> [report]`
Future<void> main(List<String> args) async {
  if (args.length != 3 && args.length != 4) {
    stderr.writeln(
      'Usage: dart run bin/report_run.dart <exit-code> <started-at> '
      '<log-file> [report-file]',
    );
    exitCode = 64;
    return;
  }

  final code = int.tryParse(args[0]) ?? 1;
  final startedAt = DateTime.tryParse(args[1]) ?? DateTime.now().toUtc();
  final log = await File(args[2]).readAsString().catchError((_) => '');
  // A report without a site (the run stopped before the first one) says
  // less than the log's last lines.
  final written = await readRunReport(args.length == 4 ? args[3] : null);
  final report = written == null || written.sites.isEmpty ? null : written;

  await withServiceClient((client) async {
    final status = report == null
        ? runStatus(code, log)
        : reportStatus(code, report);
    final problems = status == 'ok'
        ? <String>[]
        : report == null
        ? runProblems(log)
        : reportProblems(report);
    final previous = await client
        .from('collector_runs')
        .select('status, problems')
        .order('started_at', ascending: false)
        .limit(2);
    final now = DateTime.now();
    await client.from('collector_runs').insert({
      'started_at': startedAt.toUtc().toIso8601String(),
      'status': status,
      'summary': logTail(log),
      'requests': report == null
          ? requestsUsed(log)
          : {
              for (final MapEntry(:key, :value) in report.sites.entries)
                key: value.requests,
            },
      'counts': report?.counts ?? runCounts(log),
      'searches': report == null
          ? searchesRead(log)
          : [
              for (final MapEntry(:key, :value) in report.sites.entries)
                for (final search in value.searches) {'site': key, ...search},
            ],
      'problems': problems,
      'scoring_ms': report == null ? scoringMs(log) : report.scoringMs,
      'sites': {
        for (final MapEntry(key: name, value: site) in FetchSite.byName.entries)
          // No state yet: nothing used, no pause.
          name: (await readFetchState(site.statePath) ?? FetchState(day: ''))
              .report(const FetchPolicy(), now),
      },
      'run_url': githubRunUrl(Platform.environment),
    });

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 90));
    await client
        .from('collector_runs')
        .delete()
        .lt('started_at', cutoff.toIso8601String());

    stdout.writeln('Run recorded: $status');
    if (Platform.environment['GITHUB_OUTPUT'] case final output?) {
      await File(output)
          .writeAsString('status=$status\n', mode: FileMode.append);
    }

    final runs = [
      (status: status, problems: problems),
      for (final run in previous)
        (
          status: run['status'] as String,
          problems: [
            for (final p in run['problems'] as List<dynamic>? ?? const []) '$p',
          ],
        ),
    ];
    if (runHealthMessage(runs) == null) return;
    // The run is recorded; a missed message must not fail the job.
    try {
      final store = PushStore(client);
      final push = WebPushSender(
        await store.pushKeys(),
        fcm: FcmSender.fromEnvironment(),
      );
      final result = await pushToUsers(
        store,
        push,
        await store.adminIds(),
        (_, language) => runHealthMessage(runs, language: language)!,
      );
      stdout.writeln(
        'Run health sent to ${result.sent} of ${result.devices} device(s).',
      );
    } on Object catch (e) {
      stderr.writeln('Run health not sent: $e');
    }
  });
}
