import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

const _source = 'standvirtual';

Future<void> main(List<String> args) async {
  var dryRun = false;
  var max = 15;
  var badArgs = false;
  for (final arg in args) {
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--max=')) {
      max = int.tryParse(arg.substring('--max='.length)) ?? 0;
    } else {
      badArgs = true;
    }
  }
  if (badArgs || max < 1 || max > 40) {
    stderr.writeln(
      'Usage: dart run bin/enrich.dart [--dry-run] [--max=<1-40>]\n'
      '  Reads the listing page of up to <max> live listings that have no\n'
      '  details yet (newest first) and stores what it adds.',
    );
    exitCode = 64;
    return;
  }

  SupabaseClient? client;
  PoliteFetcher? fetcher;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);
    final store = ListingStore(client);

    final pending = await store.listingsMissingDetails(_source, max);
    stdout.writeln('${pending.length} listing(s) need details (limit $max).');
    if (pending.isEmpty) return;
    if (dryRun) {
      for (final p in pending) {
        stdout.writeln('  would read ${p.url}');
      }
      stdout.writeln('Dry run: nothing was requested.');
      return;
    }

    // One extra request for robots.txt.
    fetcher = PoliteFetcher(
      site: FetchSite.standvirtual,
      policy: FetchPolicy(maxRequestsPerRun: max + 1),
    );
    await fetcher.prepare();

    final updated = await enrichDetails(store, fetcher, pending);

    // Descriptions feed duplicate detection; scores follow the duplicates.
    if (updated > 0) {
      final duplicates = await store.markDuplicates();
      stdout.writeln('Duplicates flagged: $duplicates');
      final scored = await store.recalculateScores();
      stdout.writeln('Scored $scored listing(s).');
    }
  } on ConfigException catch (e) {
    stderr.writeln('Configuration error: $e');
    exitCode = 78;
  } on FetchRefused catch (e) {
    stderr.writeln('Not fetched: $e');
    exitCode = 75;
  } on FetchBlocked catch (e) {
    stderr.writeln('Stopped, the site pushed back: $e');
    exitCode = 75;
  } on FetchFailed catch (e) {
    stderr.writeln('Failed: $e');
    exitCode = 75;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    exitCode = 70;
  } finally {
    fetcher?.close();
    await client?.dispose();
  }
}
