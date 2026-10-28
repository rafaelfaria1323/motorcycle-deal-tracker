import 'dart:io';

import 'package:collector/collector.dart';

/// The photo CDN's own pace: images are small and served by a CDN, not the
/// sites' pages, but still one at a time and with a pause.
const photoPolicy = FetchPolicy(
  minDelay: Duration(seconds: 2),
  jitter: Duration(seconds: 1),
  maxRunTime: Duration(minutes: 5),
);

Future<void> main(List<String> args) async {
  var dryRun = false;
  int? max;
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
  if (badArgs || (max != null && max < 1)) {
    stderr.writeln(
      'Usage: dart run bin/photos.dart [--dry-run] [--max=<n>]\n'
      '  Fingerprints the first $photosPerListing photos of live listings\n'
      '  not fingerprinted yet (newest first) for 5 minutes at most, from\n'
      '  the photo CDN only, and finds the listings sharing them.',
    );
    exitCode = 64;
    return;
  }

  await withServiceClient((client) async {
    final store = ListingStore(client);

    final pending = await store.listingsMissingPhotoHashes(max ?? 200);
    stdout.writeln('${pending.length} listing(s) need photo fingerprints.');
    if (pending.isEmpty) return;
    if (dryRun) {
      for (final p in pending) {
        stdout.writeln('  would read ${p.images.length} photo(s) of ${p.id}');
      }
      stdout.writeln('Dry run: nothing was requested.');
      return;
    }

    final fetcher = PoliteFetcher(site: FetchSite.photos, policy: photoPolicy);
    try {
      await fetcher.prepare();
      await fingerprintPhotos(store, fetcher, pending);
    } finally {
      // Not "Requests used:": these are the CDN's, not the sites' pages.
      stdout.writeln('Photo requests: ${fetcher.requestsThisRun}');
      fetcher.close();
    }
  });
}
