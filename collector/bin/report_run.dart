import 'dart:io';

import 'package:collector/collector.dart';

/// Records one scheduled run in `collector_runs` and drops rows older than
/// 90 days. Usage: `report_run.dart <exit-code> <started-at> <log-file>`
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
    await client.from('collector_runs').insert({
      'started_at': startedAt.toUtc().toIso8601String(),
      'status': status,
      'summary': logTail(log),
      'requests': requestsUsed(log),
    });

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 90));
    await client
        .from('collector_runs')
        .delete()
        .lt('started_at', cutoff.toIso8601String());

    stdout.writeln('Run recorded: $status');
  });
}
