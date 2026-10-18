import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

const _knownFlags = {'--dry-run', '--full', '--force'};

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final positional = args.where((a) => !a.startsWith('--')).toList();

  if (positional.length != 2 ||
      positional.first != 'manual' ||
      flags.difference(_knownFlags).isNotEmpty) {
    stderr.writeln(
      'Usage: dart run bin/collector.dart manual <file.json> '
      '[--dry-run] [--full] [--force]\n'
      '  --full   the file lists EVERY live listing of this source; '
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

    // 2. Everything in this file was seen just now, new or not. A listing
    //    that had been marked removed comes back to life here.
    final unique = uniqueBySourceId(listings);
    final seenIds = [for (final l in unique) l.sourceListingId];
    final seen = await store.markSeen(adapter.source, seenIds);
    stdout.writeln('Seen $seen listing(s).');

    // 3. Known listings whose price moved get the new price and a history row.
    final changed = await store.applyPriceChanges(adapter.source, unique);
    stdout.writeln('Price changes: $changed');

    // 4. Only for a complete import: what is missing has been removed.
    //    A file with unreadable or rejected records may be incomplete, so it
    //    is never trusted to remove anything unless forced.
    if (full) {
      if (!force && (result.issues.isNotEmpty || rejected > 0)) {
        stdout.writeln(
          'Removal skipped: the file had unreadable or rejected records, so '
          'it may be incomplete (use --force to override).',
        );
      } else {
        final removed = await store.markRemoved(
          adapter.source,
          seenIds,
          force: force,
        );
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
