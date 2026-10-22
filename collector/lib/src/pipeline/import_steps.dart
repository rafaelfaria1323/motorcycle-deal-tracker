import 'dart:io';

import '../catalog/catalog.dart';
import '../normalized/normalized_listing.dart';
import '../notify/notify_pending.dart';
import '../notify/fcm.dart';
import '../notify/web_push.dart';
import '../store/listing_store.dart';
import 'source_batch.dart';

/// How an ad no followed model matched shows in the log: its brand and
/// model as the site gave them (an unmatched OLX ad's model is its title),
/// so a missed rule can be seen. Runs of 6+ digits are masked: a title may
/// hold a phone number, which the logs never show.
String unmatchedLabel(NormalizedListing listing) {
  final name = '${listing.brand} ${listing.model}'
      .replaceAll(RegExp(r'\d(?:[\s.-]?\d){5,}'), '…')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final short = name.length > 60 ? '${name.substring(0, 60)}…' : name;
  return 'unmatched "$short"';
}

/// "Search (olx): yamaha-mt-07 · read 2 of 3 page(s) · 80 ad(s), 9
/// followed · not in full", one line per planned search; [label] (else the
/// search's address) names it. "?" pages when its first page wasn't saved.
String searchReportLine(String source, SearchReport r, String? label) =>
    'Search ($source): ${label ?? r.search} · '
    'read ${r.pages} of ${r.spans ?? '?'} page(s) · '
    '${r.ads} ad(s), ${r.matched} followed · '
    '${r.inFull ? 'in full' : 'not in full'}';

/// Steps 1-4 of an import: store what the batch holds, mark it seen, apply
/// price changes and search keys, and (with [full]) remove what is gone.
/// A null [store] is a dry run: the batch is only described. [labels]
/// names searches in the log (search address -> its models).
Future<void> importBatch(
  SourceBatch batch,
  Catalog catalog, {
  required ListingStore? store,
  bool full = false,
  bool force = false,
  Map<String, String> labels = const {},
  StringSink? out,
}) async {
  final log = out ?? stdout;
  log.writeln('Source: ${batch.source}');
  log.writeln('Catalog: ${catalog.entries.length} model(s)');
  log.writeln(
    'Read ${batch.records.length + batch.issues.length} record(s), '
    '${batch.issues.length} read issue(s).',
  );
  for (final issue in batch.issues) {
    log.writeln('  ! $issue');
  }

  final listings = <NormalizedListing>[];
  var rejected = 0;
  for (final record in batch.records) {
    switch (record.outcome) {
      case Mapped(:final listing, :final warnings):
        listings.add(listing);
        log.writeln(
          '  - ${listing.motorcycleSlug ?? unmatchedLabel(listing)} · '
          '${listing.year ?? '-'} · ${listing.price} EUR · '
          '${listing.sourceListingId}',
        );
        for (final warning in warnings) {
          log.writeln('      ~ $warning');
        }
      case Rejected(:final reason):
        rejected++;
        log.writeln('  ! ${record.ref}: $reason');
    }
  }
  log.writeln('Mapped ${listings.length}, rejected $rejected.');
  for (final r in searchReports(batch)) {
    // Read back by report_run.dart (searchesRead): keep the wording.
    log.writeln(searchReportLine(batch.source, r, labels[r.search]));
  }
  if (batch.siteModels.isNotEmpty) {
    log.writeln('Brands and models on offer: ${batch.siteModels.length}');
  }

  if (store == null) {
    log.writeln('Dry run: nothing was written.');
    return;
  }

  // 1. Insert new listings (the database adds their first price-history row).
  final stored = await store.save(listings, catalog);
  log.writeln(
    'Stored ${stored.inserted} new, ${stored.alreadyStored} already stored, '
    '${stored.duplicatesInInput} duplicate(s) in the input.',
  );

  // 2. Everything in this input was seen just now, new or not. A listing
  //    that had been marked removed comes back to life here.
  final unique = uniqueBySourceId(listings);
  final seenIds = [for (final l in unique) l.sourceListingId];
  final seen = await store.markSeen(batch.source, seenIds);
  log.writeln('Seen $seen listing(s).');

  // 2a. Known listings get the model the current rules give them.
  final rematched = await store.rematch(batch.source, unique, catalog);
  if (rematched > 0) log.writeln('Model corrected: $rematched listing(s)');

  // 3. Known listings whose price moved get the new price and a history row.
  final changed = await store.applyPriceChanges(batch.source, unique);
  log.writeln('Price changes: $changed');

  // 3a. The search each listing was found by, so later runs remove only
  //     listings of the searches they read in full.
  final keys = <String, String>{
    for (final r in batch.records)
      if (r.outcome case Mapped(:final listing))
        listing.sourceListingId: ?r.search,
  };
  final keyed = await store.setSearchKeys(batch.source, keys);
  if (keys.isNotEmpty) log.writeln('Search keys updated: $keyed');

  // 3b. Cuts the site reports, which may predate our tracking. Kept apart
  //     from our own price history, so they never create alerts.
  final drops = await store.applyPricesBeforeDrop(batch.source, unique);
  log.writeln('Site-reported price cuts updated: $drops');

  // 3c. Publication and renewal dates the source shows.
  final dated = await store.applyListingDates(batch.source, unique);
  if (dated > 0) log.writeln('Listing dates updated: $dated');

  // 3d. The site's brand and model lists, for the app's model picker.
  if (batch.siteModels.isNotEmpty) {
    await store.saveSiteModels(batch.source, batch.siteModels);
  }

  // 4. Only for a complete import: what is missing has been removed.
  //    Rejected records still count as on the site (an old bike is still
  //    listed). An input with unreadable records, or a rejected one that
  //    can't be placed, may be incomplete, so it is never trusted to remove
  //    anything unless forced.
  if (full) {
    final plan = removalPlan(batch);
    final reason = plan.skipReason;
    if (reason != null && !force) {
      log.writeln('Removal skipped: $reason (use --force to override).');
    } else {
      final searches = plan.searches;
      if (searches != null) {
        log.writeln(
          'Removal covers ${searches.length} search(es) read in full'
          '${plan.includeUnkeyed ? '' : ' (listings not yet tied to a search are left alone)'}.',
        );
      }
      final removed = await store.markRemoved(
        batch.source,
        reason == null ? plan.seenIds : (liveIds(batch) ?? seenIds),
        force: force,
        searches: reason == null ? searches : null,
        includeUnkeyed: plan.includeUnkeyed,
      );
      log.writeln('Removed: $removed');
    }
  }
}

/// Steps 5-7, once per run after every import: duplicates, scores, alerts
/// and the phone notifications.
Future<void> finishRun(ListingStore store, {StringSink? out}) async {
  final log = out ?? stdout;
  // 5. Recompute. Duplicates first, so the market prices and scores that
  //    follow leave them out. Done on every run because a listing can come
  //    back or disappear without anything being inserted.
  final duplicates = await store.markDuplicates();
  log.writeln('Duplicates flagged: $duplicates');
  final scored = await store.recalculateScores();
  log.writeln('Scored $scored listing(s).');

  // 6. Last, once statuses, duplicates and prices are final: who needs to
  //    be told about what.
  final alerts = await store.generateAlerts();
  log.writeln('Alerts created: $alerts');

  // 7. Tell the phones: each account's devices (Web Push).
  WebPushSender? push;
  try {
    push = WebPushSender(
      await store.pushKeys(),
      fcm: FcmSender.fromEnvironment(),
    );
  } on Object catch (e) {
    log.writeln('Web Push not available, alerts kept for the next run: $e');
  }
  final notified = await notifyPending(store, push: push);
  log.writeln(
    'Notifications sent: ${notified.alerts} '
    '(${notified.pushes} to devices)',
  );
}
