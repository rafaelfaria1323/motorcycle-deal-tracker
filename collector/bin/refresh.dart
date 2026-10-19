import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

/// One whole collection in one process: for each site, the searches of the
/// tracked models are fetched and imported (Standvirtual then reads the
/// details of new listings with the same fetcher, so robots.txt is read
/// once and the site's request budget is shared); then duplicates, scores,
/// alerts and notifications run once. A site that fails does not stop the
/// other; the exit code still reports it.
Future<void> main(List<String> args) async {
  final sites = <FetchSite>[];
  var full = false;
  var force = false;
  var enrichMax = 10;
  var badArgs = false;
  for (final arg in args) {
    if (arg == '--full') {
      full = true;
    } else if (arg == '--force') {
      force = true;
    } else if (arg.startsWith('--site=')) {
      final site = FetchSite.byName[arg.substring('--site='.length)];
      site == null ? badArgs = true : sites.add(site);
    } else if (arg.startsWith('--enrich-max=')) {
      enrichMax = int.tryParse(arg.substring('--enrich-max='.length)) ?? -1;
    } else {
      badArgs = true;
    }
  }
  if (badArgs || enrichMax < 0 || enrichMax > 19) {
    stderr.writeln(
      'Usage: dart run bin/refresh.dart [--full] [--force] '
      '[--site=${FetchSite.byName.keys.join('|')}]... [--enrich-max=<0-19>]\n'
      '  --full   remove listings missing from searches read in full\n'
      '  --site   only this site (repeatable; default: all)\n'
      '  --enrich-max  Standvirtual listing pages to read (default 10)',
    );
    exitCode = 64;
    return;
  }
  if (sites.isEmpty) sites.addAll([FetchSite.standvirtual, FetchSite.olx]);

  final watch = Stopwatch()..start();
  SupabaseClient? client;
  var failed = 0;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);
    final store = ListingStore(client);
    final catalog = await loadCatalog(client);

    for (final site in sites) {
      final name = FetchSite.byName.entries
          .firstWhere((e) => e.value == site)
          .key;
      stdout.writeln('== $name ==');
      final code = await _refreshSite(
        site,
        name,
        catalog,
        store,
        full: full,
        force: force,
        enrichMax: enrichMax,
      );
      if (code != 0) {
        failed++;
        exitCode = code;
      }
      stdout.writeln('($name done at ${watch.elapsed.inSeconds} s)');
    }

    stdout.writeln('== all sites ==');
    await finishRun(store);
  } on ConfigException catch (e) {
    stderr.writeln('Configuration error: $e');
    exitCode = 78;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    exitCode = 70;
  } finally {
    await client?.dispose();
    stdout.writeln(
      'Refresh finished in ${watch.elapsed.inSeconds} s'
      '${failed > 0 ? ', $failed site(s) failed' : ''}.',
    );
  }
}

/// Fetches, imports and (Standvirtual) enriches one site; returns the exit
/// code for it (0 when fine).
Future<int> _refreshSite(
  FetchSite site,
  String name,
  Catalog catalog,
  ListingStore store, {
  required bool full,
  required bool force,
  required int enrichMax,
}) async {
  final plan = planSearches(catalog, site);
  for (final problem in plan.problems) {
    stderr.writeln('Skipped: $problem');
  }
  if (plan.searches.isEmpty) {
    stdout.writeln('No tracked model has a $name search, skipped.');
    return 0;
  }
  for (final s in plan.searches) {
    stdout.writeln('  search: ${s.models.join(', ')}');
  }

  final directory = 'samples/$name/search';
  await _clear(directory);

  final fetcher = PoliteFetcher(site: site);
  try {
    await fetcher.prepare();
    await fetchSearches(fetcher, [
      for (final s in plan.searches) s.url,
    ], directory);

    final batch = await loadBatch('$name-search', directory, catalog);
    await importBatch(batch, catalog, store: store, full: full, force: force);

    if (site == FetchSite.standvirtual && enrichMax > 0) {
      // New listings may be duplicates; those are never read.
      await store.markDuplicates();
      final pending = await store.listingsMissingDetails(name, enrichMax);
      stdout.writeln('${pending.length} listing(s) need details.');
      if (pending.isNotEmpty) await enrichDetails(store, fetcher, pending);
    }
    return 0;
  } on FetchLimitReached catch (e) {
    stderr.writeln('Not fetched: $e');
    return 75;
  } on FetchRefused catch (e) {
    stderr.writeln('Not fetched: $e');
    return 75;
  } on FetchBlocked catch (e) {
    stderr.writeln('Stopped, the site pushed back: $e');
    stderr.writeln('No new requests to $name for 24 hours.');
    return 75;
  } on FetchFailed catch (e) {
    stderr.writeln('Failed: $e');
    return 75;
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read the saved pages: ${e.message} (${e.path})');
    return 66;
  } on FormatException catch (e) {
    stderr.writeln('Not a search results page: ${e.message}');
    return 65;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    return 70;
  } finally {
    fetcher.close();
  }
}

/// Removes the previous run's pages and manifest.
Future<void> _clear(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) return;
  await for (final entry in dir.list()) {
    final name = entry.uri.pathSegments.last;
    if (entry is File &&
        (name.endsWith('.html') || name == SearchManifest.fileName)) {
      await entry.delete();
    }
  }
}
