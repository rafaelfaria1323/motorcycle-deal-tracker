import 'dart:io';

import 'package:collector/collector.dart';

/// Records one scheduled run in `collector_runs` (with its problems, each
/// search's pages and ads, each site's requests today and pause, and the
/// GitHub run's address), drops
/// rows older than
/// 90 days and tells the admins' devices (Web Push) when the collection
/// breaks or recovers (a change from the previous run's status only).
/// Usage: `report_run.dart <exit-code> <started-at> <log-file>`
Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run bin/report_run.dart <exit-code> <started-at> <log-file>',
    );
    exitCode = 64;
    return;
  }

  final code = int.tryParse(args[0]) ?? 1;
  final startedAt = DateTime.tryParse(args[1]) ?? DateTime.now().toUtc();
  final log = await File(args[2]).readAsString().catchError((_) => '');

  await withServiceClient((client) async {
    final status = runStatus(code, log);
    final previous = await client
        .from('collector_runs')
        .select('status')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final now = DateTime.now();
    await client.from('collector_runs').insert({
      'started_at': startedAt.toUtc().toIso8601String(),
      'status': status,
      'summary': logTail(log),
      'requests': requestsUsed(log),
      'counts': runCounts(log),
      'searches': searchesRead(log),
      'problems': status == 'ok' ? <String>[] : runProblems(log),
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

    final message = runHealthMessage(
      previous: previous?['status'] as String?,
      current: status,
      log: log,
    );
    if (message == null) return;
    // The run is recorded; a missed message must not fail the job.
    try {
      final store = ListingStore(client);
      final push = WebPushSender(
        await store.pushKeys(),
        fcm: FcmSender.fromEnvironment(),
      );
      final result = await pushToUsers(
        store,
        push,
        await store.adminIds(),
        (language) => runHealthMessage(
          previous: previous?['status'] as String?,
          current: status,
          log: log,
          language: language,
        )!,
      );
      stdout.writeln(
        'Run health sent to ${result.sent} of ${result.devices} device(s).',
      );
    } on Object catch (e) {
      stderr.writeln('Run health not sent: $e');
    }
  });
}
