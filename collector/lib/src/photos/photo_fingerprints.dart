import 'dart:io';

import '../fetch/polite_fetcher.dart';
import '../store/listing_store.dart';
import 'photo_hash.dart';

/// How many photos of each listing are fingerprinted: the first ones are
/// the ones a relist or a copied ad reuses, and each is one request.
const photosPerListing = 3;

/// Downloads the first [photosPerListing] photos of each of [pending] with
/// [fetcher] (prepared, on the photo CDN), stores their hashes and returns
/// how many listings were fingerprinted. A photo that is gone, refused by
/// our rules or unreadable is left out (a listing with none still counts as
/// done, so it is not asked for again). Running out of time stops quietly;
/// a block, transport failure or other HTTP error stops and is rethrown
/// once what was read is stored.
Future<int> fingerprintPhotos(
  ListingStore store,
  PoliteFetcher fetcher,
  List<({String id, List<String> images})> pending, {
  StringSink? out,
}) async {
  final log = out ?? stdout;
  final hashes = <({String id, List<int> hashes})>[];
  Exception? stop;

  try {
    for (final p in pending) {
      final read = <int>[];
      for (final url in p.images.take(photosPerListing)) {
        final hash = await _hashOf(fetcher, url, log);
        if (hash != null) read.add(hash);
      }
      hashes.add((id: p.id, hashes: read));
      log.writeln('  ${p.id}: ${read.length} photo(s)');
    }
  } on FetchLimitReached catch (e) {
    log.writeln('Stopped: $e; the rest waits for the next run.');
  } on FetchBlocked catch (e) {
    stop = e;
  } on FetchFailed catch (e) {
    stop = e;
  }

  // Keep whatever was read before a stop.
  final stored = await store.storePhotoHashes(hashes);
  log.writeln('Photo fingerprints stored for $stored listing(s).');
  if (stop != null) throw stop;
  return stored;
}

/// One photo's hash; null when it is gone, refused or not an image.
Future<int?> _hashOf(PoliteFetcher fetcher, String url, StringSink log) async {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    log.writeln('  - skipped $url: not an address');
    return null;
  }
  try {
    final hash = photoHash(await fetcher.getImage(uri));
    if (hash == null) log.writeln('  - skipped $url: not a readable image');
    return hash;
  } on FetchFailed catch (e) {
    if (e.statusCode != 404 && e.statusCode != 410) rethrow;
    log.writeln('  - skipped $url: $e');
  } on FetchLimitReached {
    rethrow;
  } on FetchRefused catch (e) {
    log.writeln('  - skipped $url: $e');
  }
  return null;
}
