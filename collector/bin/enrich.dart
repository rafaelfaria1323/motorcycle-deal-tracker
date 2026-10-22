import 'dart:io';

import 'package:collector/collector.dart';

const _source = 'standvirtual';

Future<void> main(List<String> args) async {
  var dryRun = false;
  var max = 10;
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
  if (badArgs || max < 1) {
    stderr.writeln(
      'Usage: dart run bin/enrich.dart [--dry-run] [--max=<n>] (default 10)\n'
      '  Reads the listing page of up to <max> live listings that have no\n'
      '  details yet (newest first, pages that failed before last) and\n'
      '  stores what it adds.',
    );
    exitCode = 64;
    return;
  }

  await withServiceClient((client) async {
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
    final fetcher = PoliteFetcher(
      site: FetchSite.standvirtual,
      policy: FetchPolicy(maxRequestsPerRun: max + 1),
    );
    try {
      await fetcher.prepare();
      final updated = await enrichDetails(store, fetcher, pending);

      // Descriptions feed duplicate detection; scores follow the duplicates.
      if (updated > 0) {
        final duplicates = await store.markDuplicates();
        stdout.writeln('Duplicates flagged: $duplicates');
        final scored = await store.recalculateScores();
        stdout.writeln('Scored $scored listing(s).');
      }
    } finally {
      fetcher.close();
    }
  });
}
