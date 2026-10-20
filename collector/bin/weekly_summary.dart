import 'dart:io';

import 'package:collector/collector.dart';

/// Sends the week's summary of the tracked models to Telegram: new
/// listings, price drops, listings gone and the best deals now.
/// `--dry-run` prints it instead.
Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final notifier = TelegramNotifier.fromEnvironment();
  if (notifier == null && !dryRun) {
    stderr.writeln(
      'Telegram not configured: set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.',
    );
    exitCode = 78;
    return;
  }

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

    final text = formatWeeklySummary(
      buildWeeklySummary(listings: listings, history: history, until: until),
    );
    if (dryRun) {
      stdout.writeln(text);
      return;
    }
    await notifier!.send(text, linkPreview: false);
    stdout.writeln('Weekly summary sent.');
  });
}
