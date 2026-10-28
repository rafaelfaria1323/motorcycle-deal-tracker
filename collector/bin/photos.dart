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
      '  the photo CDN only, and finds the listings sharing them. With\n'
      '  PHOTO_MODEL_DIR set (tool/photo_model.sh), the same photos are\n'
      '  also shown to the image model for damage hints (P.2), with\n'
      '  PHOTO_PYTHON (python3 by default) running tool/photo_examine.py.',
    );
    exitCode = 64;
    return;
  }

  final modelDir = Platform.environment['PHOTO_MODEL_DIR'] ?? '';
  await withServiceClient((client) async {
    final store = ListingStore(client);
    // Started before asking which listings wait: without a model, listings
    // already fingerprinted are not asked for again.
    final examiner = modelDir.isEmpty || dryRun
        ? null
        : await ProcessPhotoExaminer.start(
            python: Platform.environment['PHOTO_PYTHON'] ?? 'python3',
            script: '../tool/photo_examine.py',
            modelDir: modelDir,
            log: stdout,
          );
    try {
      final pending = await store.listingsMissingPhotoChecks(
        max ?? 200,
        examine: examiner != null || (dryRun && modelDir.isNotEmpty),
      );
      stdout.writeln('${pending.length} listing(s) need photo checks.');
      if (pending.isEmpty) return;
      if (dryRun) {
        for (final p in pending) {
          stdout.writeln('  would read ${p.images.length} photo(s) of ${p.id}');
        }
        stdout.writeln('Dry run: nothing was requested.');
        return;
      }

      final fetcher = PoliteFetcher(
        site: FetchSite.photos,
        policy: photoPolicy,
      );
      try {
        await fetcher.prepare();
        await fingerprintPhotos(store, fetcher, pending, examiner: examiner);
      } finally {
        // Not "Requests used:": these are the CDN's, not the sites' pages.
        stdout.writeln('Photo requests: ${fetcher.requestsThisRun}');
        fetcher.close();
      }
    } finally {
      await examiner?.close();
    }
  });
}
