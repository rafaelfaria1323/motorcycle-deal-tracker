import 'dart:io';

import 'package:collector/collector.dart';

/// Makes each account's summary of its own models' last 7 days (new
/// listings, price drops, listings gone and the best deals now), keeps it
/// for the app's "Resumo da semana" and sends it to the account's devices
/// (Web Push). `SUMMARY_ACCOUNT` (the account that asked in the app) makes
/// only that account's; empty, every account's. `--dry-run` prints them
/// instead.
Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final account = Platform.environment['SUMMARY_ACCOUNT']?.trim();

  await withServiceClient((client) async {
    final store = ListingStore(client);

    final catalog = await loadCatalog(client);
    final bikeNames = {
      for (final e in catalog.entries) ?e.id: '${e.brand} ${e.model}',
    };
    final until = DateTime.now().toUtc();
    final since = until.subtract(const Duration(days: 7));
    final listings = await store.summaryListings(bikeNames, since);
    final history = await store.priceHistoryChangedSince({
      for (final l in listings)
        if (l.isLive) l.id,
    }, since);

    final summaries = summariesByAccount(
      follows: await store.followedModels(),
      listings: listings,
      history: history,
      until: until,
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
    final push = WebPushSender(await store.pushKeys());
    final result = await sendWeeklySummaries(store, push, summaries);
    stdout.writeln(
      'Weekly summary made for ${result.accounts} account(s), sent to '
      '${result.sent} of ${result.devices} device(s).',
    );
  });
}
