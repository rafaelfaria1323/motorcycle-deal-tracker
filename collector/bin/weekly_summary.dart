import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

/// Makes each account's summary of its own models' last 7 days (new
/// listings, price drops, listings gone and the best deals now), keeps it
/// for the app's "Resumo da semana" and sends it to the account's devices
/// (Web Push). `SUMMARY_ACCOUNT` (the account that asked in the app) makes
/// only that account's; empty, every account's. `--dry-run` prints them
/// instead.
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()..addFlag(
      'dry-run',
      negatable: false,
      help: 'Print the summaries; nothing is kept or sent.',
    ),
    args,
    usage: 'Usage: dart run bin/weekly_summary.dart [options]',
  );
  if (options == null) return;
  final dryRun = options.flag('dry-run');
  final account = Platform.environment['SUMMARY_ACCOUNT']?.trim();

  await withServiceClient((client) async {
    final store = SummaryStore(client);
    final pushes = PushStore(client);

    final catalog = await loadCatalog(client);
    final bikeNames = {
      for (final e in catalog.entries) ?e.id: '${e.brand} ${e.model}',
    };
    final summaries = await loadWeeklySummaries(
      store,
      bikeNames,
      until: DateTime.now().toUtc(),
      account: account == null || account.isEmpty ? null : account,
    );
    if (dryRun) {
      for (final MapEntry(key: user, value: s) in summaries.entries) {
        stdout
          ..writeln('Account $user')
          ..writeln(weeklySummaryPush(s))
          ..writeln(weeklySummaryJson(s));
      }
      return;
    }
    final push = WebPushSender(
      await pushes.pushKeys(),
      fcm: FcmSender.fromEnvironment(),
    );
    final result = await sendWeeklySummaries(store, pushes, push, summaries);
    stdout.writeln(
      'Weekly summary made for ${result.accounts} account(s), sent to '
      '${result.sent} of ${result.devices} device(s).',
    );
  });
}
