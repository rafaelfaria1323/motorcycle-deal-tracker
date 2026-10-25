import 'dart:io';

import '../adapters/standvirtual/standvirtual_page_adapter.dart';
import '../fetch/polite_fetcher.dart';
import '../normalized/listing_details.dart';
import '../store/listing_store.dart';

const _source = 'standvirtual';

/// Reads the Standvirtual listing page of each of [pending] with [fetcher]
/// (prepared) and stores the details they add; returns how many listings
/// were updated. A page that is gone, unreadable or refused by our own
/// rules (e.g. a redirect off /motos/) is skipped and marked failed, and so
/// is one that turns out to be another ad, so the next runs try the
/// listings never read first. Running out of requests
/// stops quietly; a block, transport failure or other HTTP error stops
/// and is rethrown once what was read is stored.
Future<int> enrichDetails(
  ListingStore store,
  PoliteFetcher fetcher,
  List<({String sourceListingId, String url})> pending, {
  StringSink? out,
}) async {
  final log = out ?? stdout;
  final adapter = StandvirtualPageAdapter('unused');
  final details = <ListingDetails>[];
  final failed = <String>[];
  Object? stop;

  try {
    for (final p in pending) {
      try {
        final html = await fetcher.get(Uri.parse(p.url));
        final read = adapter.parseDetails(html);
        if (read.sourceListingId != p.sourceListingId) {
          // Redirected to another ad: this one has no page of its own.
          failed.add(p.sourceListingId);
          log.writeln(
            '  - skipped ${p.sourceListingId}: the page is '
            '${read.sourceListingId}',
          );
          continue;
        }
        details.add(read);
        log.writeln('  read ${p.sourceListingId}');
      } on FetchFailed catch (e) {
        failed.add(p.sourceListingId);
        if (e.statusCode != 404 && e.statusCode != 410) rethrow;
        log.writeln('  - skipped ${p.sourceListingId}: $e');
      } on FormatException catch (e) {
        failed.add(p.sourceListingId);
        log.writeln('  - skipped ${p.sourceListingId}: ${e.message}');
      } on FetchLimitReached {
        rethrow;
      } on FetchRefused catch (e) {
        failed.add(p.sourceListingId);
        log.writeln('  - skipped ${p.sourceListingId}: $e');
      }
    }
  } on FetchLimitReached catch (e) {
    log.writeln('Stopped: $e; the rest waits for the next run.');
  } on FetchBlocked catch (e) {
    stop = e;
  } on FetchFailed catch (e) {
    stop = e;
  }

  // Keep whatever was read before a stop.
  final updated = await store.applyDetails(_source, details);
  await store.markDetailsFailed(_source, failed);
  log.writeln(
    'Details stored for $updated listing(s), ${failed.length} skipped.',
  );
  if (stop != null) throw stop;
  return updated;
}
