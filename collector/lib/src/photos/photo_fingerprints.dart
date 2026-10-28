import 'dart:io';

import '../fetch/polite_fetcher.dart';
import '../store/listing_store.dart';
import 'photo_examiner.dart';
import 'photo_hash.dart';

/// How many photos of each listing are fingerprinted: the first ones are
/// the ones a relist or a copied ad reuses, and each is one request.
const photosPerListing = 3;

/// The examiner's answer on one photo of a listing ([photo]: its place in
/// the listing's images, from 0).
typedef PhotoFeatures = ({int photo, PhotoExamination examination});

/// Downloads the first [photosPerListing] photos of each of [pending] with
/// [fetcher] (prepared, on the photo CDN), stores their hashes and returns
/// how many listings were fingerprinted. A photo that is gone, refused by
/// our rules or unreadable is left out (a listing with none still counts as
/// done, so it is not asked for again). Running out of time stops quietly;
/// a block, transport failure or other HTTP error stops and is rethrown
/// once what was read is stored.
///
/// With an [examiner] (P.2) each photo read is also shown to the image
/// model, from memory: no extra request. A listing counts as examined only
/// when the examiner lasted through all its photos; if it fails, the rest
/// are only fingerprinted and wait for their hints.
Future<int> fingerprintPhotos(
  ListingStore store,
  PoliteFetcher fetcher,
  List<({String id, List<String> images})> pending, {
  PhotoExaminer? examiner,
  StringSink? out,
}) async {
  final log = out ?? stdout;
  final hashes = <({String id, List<int> hashes})>[];
  final examined = <({String id, List<PhotoFeatures> photos})>[];
  var looking = examiner;
  Exception? stop;

  try {
    for (final p in pending) {
      final read = <int>[];
      final seen = <PhotoFeatures>[];
      for (final (index, url) in p.images.take(photosPerListing).indexed) {
        final photo = await _photoOf(fetcher, url, log);
        if (photo == null) continue;
        final hash = photoHash(photo);
        if (hash == null) {
          log.writeln('  - skipped $url: not a readable image');
          continue;
        }
        read.add(hash);
        if (looking == null) continue;
        try {
          final answer = await looking.examine(photo);
          if (answer != null) seen.add((photo: index, examination: answer));
        } on PhotoExaminerFailed catch (e) {
          log.writeln('Photo hints stopped: $e; the rest wait for them.');
          looking = null;
        }
      }
      hashes.add((id: p.id, hashes: read));
      if (looking != null) examined.add((id: p.id, photos: seen));
      log.writeln('  ${p.id}: ${read.length} photo(s)');
    }
  } on FetchLimitReached catch (e) {
    log.writeln('Stopped: $e; the rest waits for the next run.');
  } on FetchDisallowed catch (e) {
    // The CDN's rules cover every photo alike: the listing being read and
    // the rest stay unchecked, so a change of rules brings them back.
    log.writeln('Stopped: $e; the rest waits until it is allowed.');
  } on FetchBlocked catch (e) {
    stop = e;
  } on FetchFailed catch (e) {
    stop = e;
  }

  // Keep whatever was read before a stop.
  final stored = await store.storePhotoHashes(hashes);
  log.writeln('Photo fingerprints stored for $stored listing(s).');
  if (examiner != null) {
    final hinted = await store.storePhotoFeatures(examiner.model, examined);
    log.writeln('Photo hints stored for $hinted listing(s).');
  }
  if (stop != null) throw stop;
  return stored;
}

/// One photo's bytes; null when it is gone or refused.
Future<List<int>?> _photoOf(
  PoliteFetcher fetcher,
  String url,
  StringSink log,
) async {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    log.writeln('  - skipped $url: not an address');
    return null;
  }
  try {
    return await fetcher.getImage(uri);
  } on FetchFailed catch (e) {
    if (e.statusCode != 404 && e.statusCode != 410) rethrow;
    log.writeln('  - skipped $url: $e');
  } on FetchLimitReached {
    rethrow;
  } on FetchDisallowed {
    rethrow;
  } on FetchRefused catch (e) {
    log.writeln('  - skipped $url: $e');
  }
  return null;
}
