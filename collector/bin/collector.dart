import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final positional = args.where((a) => a != '--dry-run').toList();

  if (positional.length != 2 || positional.first != 'manual') {
    stderr.writeln(
      'Usage: dart run bin/collector.dart manual <file.json> [--dry-run]',
    );
    exitCode = 64;
    return;
  }

  SupabaseClient? client;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);

    final catalog = await loadCatalog(client);
    final adapter = ManualAdapter(positional[1]);
    final mapper = ManualMapper(catalog);

    stdout.writeln('Source: ${adapter.source}');
    stdout.writeln('Catalog: ${catalog.entries.length} model(s)');

    final result = await adapter.read();
    stdout.writeln(
      'Read ${result.records.length} record(s), '
      '${result.issues.length} read issue(s).',
    );
    for (final issue in result.issues) {
      stdout.writeln('  ! $issue');
    }

    final listings = <NormalizedListing>[];
    var rejected = 0;
    for (final raw in result.records) {
      switch (mapper.map(raw)) {
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
          stdout.writeln('  ! ${raw.url}: $reason');
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
      '${stored.duplicatesInInput} duplicate(s) in the file.',
    );

    // 2. Everything in this file was seen just now, new or not.
    final unique = uniqueBySourceId(listings);
    final seen = await store.markSeen(adapter.source, [
      for (final l in unique) l.sourceListingId,
    ]);
    stdout.writeln('Seen $seen listing(s).');

    // 3. Known listings whose price moved get the new price and a history row.
    final changed = await store.applyPriceChanges(adapter.source, unique);
    stdout.writeln('Price changes: $changed');

    // 4. Only recompute when something actually changed. Duplicates first, so
    //    the market prices and scores that follow leave them out.
    if (stored.inserted > 0 || changed > 0) {
      final duplicates = await store.markDuplicates();
      stdout.writeln('Duplicates flagged: $duplicates');
      final scored = await store.recalculateScores();
      stdout.writeln('Scored $scored listing(s).');
    }
  } on ConfigException catch (e) {
    stderr.writeln('Configuration error: $e');
    exitCode = 78;
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read file: ${e.message} (${e.path})');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('Invalid file: ${e.message}');
    exitCode = 65;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    exitCode = 70;
  } finally {
    await client?.dispose();
  }
}
