import 'dart:io';

import '../adapters/standvirtual/standvirtual_page_adapter.dart';
import '../fetch/polite_fetcher.dart';
import '../normalized/listing_details.dart';
import '../store/listing_store.dart';

const _source = 'standvirtual';

/// Reads the Standvirtual listing page of each of [pending] with [fetcher]
/// (prepared) and stores the details they add; returns how many listings
/// were updated. A page that is gone, unreadable or refused by our own
/// rules (e.g. a redirect off /motos/) is skipped. Running out of requests
/// stops quietly; a block stops too, and is rethrown once what was read is
/// stored.
Future<int> enrichDetails(
  ListingStore store,
  PoliteFetcher fetcher,
  List<({String sourceListingId, String url})> pending, {
  StringSink? out,
}) async {
  final log = out ?? stdout;
  final adapter = StandvirtualPageAdapter('unused');
  final details = <ListingDetails>[];
  var skipped = 0;
  FetchBlocked? stop;

  try {
    for (final p in pending) {
      try {
        final html = await fetcher.get(Uri.parse(p.url));
        details.add(adapter.parseDetails(html));
        log.writeln('  read ${p.sourceListingId}');
      } on FetchFailed catch (e) {
        // e.g. 404 for a listing removed since the last search: skip it.
        skipped++;
        log.writeln('  - skipped ${p.sourceListingId}: $e');
      } on FormatException catch (e) {
        skipped++;
        log.writeln('  - skipped ${p.sourceListingId}: ${e.message}');
      } on FetchLimitReached {
        rethrow;
      } on FetchRefused catch (e) {
        skipped++;
        log.writeln('  - skipped ${p.sourceListingId}: $e');
      }
    }
  } on FetchLimitReached catch (e) {
    log.writeln('Stopped: $e; the rest waits for the next run.');
  } on FetchBlocked catch (e) {
    stop = e;
  }

  // Keep whatever was read before a stop.
  final updated = await store.applyDetails(_source, details);
  log.writeln('Details stored for $updated listing(s), $skipped skipped.');
  if (stop != null) throw stop;
  return updated;
}
