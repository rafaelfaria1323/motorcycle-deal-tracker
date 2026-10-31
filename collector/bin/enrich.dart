import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

const _source = 'standvirtual';

Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addFlag('dry-run', negatable: false, help: 'Nothing is requested.')
      ..addOption('max', defaultsTo: '10', help: 'Listing pages to read.'),
    args,
    atLeast: {'max': 1},
    usage:
        'Usage: dart run bin/enrich.dart [options]\n'
        '  Reads the listing page of up to <max> live listings that have no\n'
        '  details yet (favourites, alerted ones, then by Deal Score; pages\n'
        '  that failed before last) and stores what it adds.',
  );
  if (options == null) return;
  final dryRun = options.flag('dry-run');
  final max = intOption(options, 'max')!;

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

    // One extra request for robots.txt, when the one kept is 24 h old.
    final fetcher = PoliteFetcher(
      site: .standvirtual,
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
