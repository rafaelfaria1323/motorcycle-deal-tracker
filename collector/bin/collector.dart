import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

const _knownFlags = {'--dry-run', '--full', '--force'};

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final positional = args.where((a) => !a.startsWith('--')).toList();

  if (positional.length != 2 || !sourceKinds.contains(positional.first) || flags.difference(_knownFlags).isNotEmpty) {
    stderr.writeln(
      'Usage: dart run bin/collector.dart <${sourceKinds.join('|')}> <path> '
      '[--dry-run] [--full] [--force]\n'
      '  manual        <path> is a JSON file\n'
      '  standvirtual  <path> is a folder of page results\n'
      '  standvirtual-search  <path> is a folder of search results pages\n'
      '  --full   the input lists EVERY live listing of this source; '
      'listings missing from it are marked removed\n'
      '  --force  skip the safety limit on removals',
    );
    exitCode = 64;
    return;
  }
  final dryRun = flags.contains('--dry-run');
  final full = flags.contains('--full');
  final force = flags.contains('--force');

  SupabaseClient? client;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);

    final catalog = await loadCatalog(client);
    final batch = await loadBatch(positional.first, positional[1], catalog);

    stdout.writeln('Source: ${batch.source}');
    stdout.writeln('Catalog: ${catalog.entries.length} model(s)');
    stdout.writeln(
      'Read ${batch.records.length + batch.issues.length} record(s), '
      '${batch.issues.length} read issue(s).',
    );
    for (final issue in batch.issues) {
      stdout.writeln('  ! $issue');
    }

    final listings = <NormalizedListing>[];
    var rejected = 0;
    for (final record in batch.records) {
      switch (record.outcome) {
        case Mapped(:final listing, :final warnings):
          listings.add(listing);
          stdout.writeln(
            '  - ${listing.motorcycleSlug ?? 'unmatched'} · '
            '${listing.year ?? '-'} · ${listing.price} EUR · '
            '${listing.sourceListingId}',
          );
          for (final warning in warnings) {
            stdout.writeln('      ~ $warning');
          }
        case Rejected(:final reason):
          rejected++;
          stdout.writeln('  ! ${record.ref}: $reason');
      }
    }
    stdout.writeln('Mapped ${listings.length}, rejected $rejected.');

    if (dryRun) {
      stdout.writeln('Dry run: nothing was written.');
      return;
    }

    final store = ListingStore(client);

    // 1. Insert new listings (the database adds their first price-history row).
    final stored = await store.save(listings, catalog);
    stdout.writeln(
      'Stored ${stored.inserted} new, ${stored.alreadyStored} already stored, '
      '${stored.duplicatesInInput} duplicate(s) in the input.',
    );

    // 2. Everything in this input was seen just now, new or not. A listing
    //    that had been marked removed comes back to life here.
    final unique = uniqueBySourceId(listings);
    final seenIds = [for (final l in unique) l.sourceListingId];
    final seen = await store.markSeen(batch.source, seenIds);
    stdout.writeln('Seen $seen listing(s).');

    // 3. Known listings whose price moved get the new price and a history row.
    final changed = await store.applyPriceChanges(batch.source, unique);
    stdout.writeln('Price changes: $changed');

    // 3b. Cuts the site reports, which may predate our tracking. Kept apart
    //     from our own price history, so they never create alerts.
    final drops = await store.applyPricesBeforeDrop(batch.source, unique);
    stdout.writeln('Site-reported price cuts updated: $drops');

    // 4. Only for a complete import: what is missing has been removed.
    //    An input with unreadable or rejected records may be incomplete, so it
    //    is never trusted to remove anything unless forced.
    if (full) {
      if (!force && (batch.issues.isNotEmpty || rejected > 0)) {
        stdout.writeln(
          'Removal skipped: the input had unreadable or rejected records, so '
          'it may be incomplete (use --force to override).',
        );
      } else {
        final removed = await store.markRemoved(batch.source, seenIds, force: force);
        stdout.writeln('Removed: $removed');
      }
    }

    // 5. Recompute. Duplicates first, so the market prices and scores that
    //    follow leave them out. Done on every run because a listing can come
    //    back or disappear without anything being inserted.
    final duplicates = await store.markDuplicates();
    stdout.writeln('Duplicates flagged: $duplicates');
    final scored = await store.recalculateScores();
    stdout.writeln('Scored $scored listing(s).');

    // 6. Last, once statuses, duplicates and prices are final: who needs to
    //    be told about what.
    final alerts = await store.generateAlerts();
    stdout.writeln('Alerts created: $alerts');

    // 7. Push what's new to the phone, when Telegram is configured.
    final notifier = TelegramNotifier.fromEnvironment();
    if (notifier != null) {
      final pushed = await notifyPending(store, notifier);
      stdout.writeln('Notifications sent: $pushed');
    } else {
      stdout.writeln('Notifications: Telegram not configured');
    }
  } on ConfigException catch (e) {
    stderr.writeln('Configuration error: $e');
    exitCode = 78;
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read input: ${e.message} (${e.path})');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('Invalid input: ${e.message}');
    exitCode = 65;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    exitCode = 70;
  } finally {
    await client?.dispose();
  }
}
