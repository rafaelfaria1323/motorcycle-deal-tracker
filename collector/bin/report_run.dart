import 'dart:io';

import 'package:collector/collector.dart';

/// Records one scheduled run in `collector_runs`, drops rows older than
/// 90 days and tells Telegram when the collection breaks or recovers (a
/// change from the previous run's status only).
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
    await client.from('collector_runs').insert({
      'started_at': startedAt.toUtc().toIso8601String(),
      'status': status,
      'summary': logTail(log),
      'requests': requestsUsed(log),
      'counts': runCounts(log),
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
    final notifier = TelegramNotifier.fromEnvironment();
    if (message == null || notifier == null) return;
    try {
      await notifier.send(message, linkPreview: false);
      stdout.writeln('Run health sent to Telegram.');
    } on NotifyFailed catch (e) {
      // The run is recorded; a missed message must not fail the job.
      stderr.writeln('Run health not sent: $e');
    }
  });
}
