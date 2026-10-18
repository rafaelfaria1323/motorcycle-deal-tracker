import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final positional = args.where((a) => a != '--dry-run').toList();

  if (positional.length != 2 || positional.first != 'manual') {
    stderr.writeln('Usage: dart run bin/collector.dart manual <file.json> [--dry-run]');
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
    final stored = await store.save(listings, catalog);
    final seen = await store.markSeen(
      adapter.source, // 'manual'
      uniqueBySourceId(listings).map((l) => l.sourceListingId).toList(),
    );
    stdout.writeln('Seen $seen listing(s).');
    stdout.writeln(
      'Stored ${stored.inserted} new, ${stored.alreadyStored} already stored, '
      '${stored.duplicatesInInput} duplicate(s) in the file.',
    );

    if (stored.inserted > 0) {
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
