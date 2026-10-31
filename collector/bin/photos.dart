import 'dart:io';

import 'package:collector/collector.dart';

/// The photo CDN's own pace: images are small and served by a CDN, not the
/// sites' pages, but still one at a time and with a pause.
const photoPolicy = FetchPolicy(
  minDelay: Duration(seconds: 2),
  jitter: Duration(seconds: 1),
  maxRunTime: Duration(minutes: 5),
);

/// At most this many ads examined in full per run (P.4): 30 photos about
/// 3 s apart take about a minute and a half each, of the run's 5 minutes.
const maxExamsPerRun = 3;

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
      '  PHOTO_PYTHON (python3 by default) running tool/photo_examine.py;\n'
      '  then a classifier is trained on the admins\' photo marks (P.3)\n'
      '  when they changed, and the ads someone asked to examine in full\n'
      '  (P.4) have up to $photosPerExam photos examined, first.',
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
      // The admins' marks first (P.3), so the photos examined below already
      // get the hint learned from them.
      if (examiner != null) await trainOnPhotoMarks(store, examiner.model);
      final examine = examiner != null || (dryRun && modelDir.isNotEmpty);
      // The ads someone asked to examine in full (P.4) go first: they were
      // asked for and wait for no one else.
      final exams = examine
          ? await store.listingsAwaitingPhotoExam(maxExamsPerRun)
          : const <({String id, List<String> images})>[];
      final asked = {for (final e in exams) e.id};
      final pending = [
        ...exams,
        for (final p in await store.listingsMissingPhotoChecks(
          max ?? 200,
          examine: examine,
        ))
          if (!asked.contains(p.id)) p,
      ];
      if (exams.isNotEmpty) {
        stdout.writeln('${exams.length} listing(s) asked to examine in full.');
      }
      stdout.writeln('${pending.length} listing(s) need photo checks.');
      if (pending.isEmpty) return;
      if (dryRun) {
        for (final p in pending) {
          stdout.writeln('  would read ${p.images.length} photo(s) of ${p.id}');
        }
        stdout.writeln('Dry run: nothing was requested.');
        return;
      }

      final fetcher = PoliteFetcher(site: .photos, policy: photoPolicy);
      try {
        await fetcher.prepare();
        await fingerprintPhotos(
          store,
          fetcher,
          pending,
          examiner: examiner,
          exams: asked,
        );
      } finally {
        // Not "Requests used:": these are the CDN's, not the sites' pages.
        stdout.writeln('Photo requests: ${fetcher.requestsThisRun}');
        fetcher.close();
        // Also after a stop: the examinations stored before it are done.
        await _tellAskers(store, asked.toList());
      }
    } finally {
      await examiner?.close();
    }
  });
}

/// Tells whoever asked for the examinations of [asked] that finished on
/// their devices. A push that can't go out loses nothing: the hints show
/// in the app.
Future<void> _tellAskers(ListingStore store, List<String> asked) async {
  if (asked.isEmpty) return;
  try {
    final push = WebPushSender(
      await store.pushKeys(),
      fcm: FcmSender.fromEnvironment(),
    );
    final sent = await tellPhotoExams(store, push, asked);
    stdout.writeln('Photo exams told: $sent push(es) to devices.');
  } on Object catch (e) {
    stdout.writeln('Photo exams not told on devices: $e');
  }
}
