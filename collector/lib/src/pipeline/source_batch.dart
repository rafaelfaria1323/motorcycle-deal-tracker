import '../adapters/manual/manual_adapter.dart';
import '../adapters/manual/manual_mapper.dart';
import '../adapters/olx/olx_mapper.dart';
import '../adapters/olx/olx_search_adapter.dart';
import '../adapters/site_model.dart';
import '../adapters/source_adapter.dart';
import '../adapters/standvirtual/standvirtual_mapper.dart';
import '../adapters/standvirtual/standvirtual_page_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import '../catalog/catalog.dart';
import '../fetch/search_manifest.dart';
import '../normalized/normalized_listing.dart';
import '../normalized/normalizers.dart';

/// One record after mapping, with something to name it by in the output.
class MappedRecord {
  const MappedRecord(this.ref, this.outcome, {this.liveId, this.search});

  final String ref;
  final MapOutcome outcome;

  /// The listing's source id when the source shows it as live, whatever we
  /// made of it: a bike we reject (too old, say) is still on the site, so it
  /// was seen. Null when the record says the listing is gone.
  final String? liveId;

  /// The search that found it, when the input has a [SearchManifest].
  final String? search;
}

/// Source ids of every listing the input shows as live, rejected or not.
/// Null when a rejected record can't be placed, so the input can't be
/// trusted to say what was removed.
List<String>? liveIds(SourceBatch batch) {
  final ids = <String>{};
  for (final record in batch.records) {
    switch (record.outcome) {
      case Mapped(:final listing):
        ids.add(listing.sourceListingId);
      case Rejected():
        final id = record.liveId;
        if (id == null) return null;
        ids.add(id);
    }
  }
  return ids.toList();
}

/// Everything one run read from one source, already mapped.
class SourceBatch {
  const SourceBatch(
    this.source,
    this.issues,
    this.records, {
    this.manifest,
    this.siteModels = const [],
  });

  final String source;
  final List<ParseIssue> issues;
  final List<MappedRecord> records;

  /// What the fetch run planned and saved; null for inputs without one.
  final SearchManifest? manifest;

  /// The brands and models the site offers (search pages only).
  final List<SiteModel> siteModels;
}

/// What a complete import may mark as removed.
class RemovalPlan {
  const RemovalPlan.skip(String this.skipReason)
    : seenIds = const [],
      searches = null,
      includeUnkeyed = false;

  const RemovalPlan.remove(
    this.seenIds, {
    this.searches,
    this.includeUnkeyed = true,
  }) : skipReason = null;

  /// Why nothing may be removed; null when removal goes ahead.
  final String? skipReason;

  /// Every listing the input shows as live.
  final List<String> seenIds;

  /// The searches read in full: only their listings may be removed. Null
  /// for an input without searches, which covers the whole source.
  final List<String>? searches;

  /// Whether listings no search has claimed yet are covered too: only when
  /// every planned search was read in full.
  final bool includeUnkeyed;
}

/// How many of the ads a search read are a followed model, per search in
/// the order planned. A search whose ads are mostly other bikes spends the
/// request budget for little (OLX's word searches match any of their
/// words). Empty without a manifest.
List<({String search, int ads, int matched})> searchYields(SourceBatch batch) {
  final manifest = batch.manifest;
  if (manifest == null) return const [];
  final ads = <String, int>{};
  final matched = <String, int>{};
  for (final record in batch.records) {
    final search = record.search;
    if (search == null) continue;
    ads[search] = (ads[search] ?? 0) + 1;
    if (record.outcome case Mapped(
      :final listing,
    ) when listing.motorcycleSlug != null) {
      matched[search] = (matched[search] ?? 0) + 1;
    }
  }
  return [
    for (final search in manifest.planned)
      if (ads[search] case final count?)
        (search: search, ads: count, matched: matched[search] ?? 0),
  ];
}

/// Decides what may be removed. Without a manifest the input must be clean
/// as a whole; with one, each search stands on its own: a search with a
/// problem, or not fetched at all, keeps its listings, and the others go
/// ahead.
RemovalPlan removalPlan(SourceBatch batch) {
  final manifest = batch.manifest;
  if (manifest == null) {
    final live = liveIds(batch);
    if (batch.issues.isNotEmpty || live == null) {
      return const RemovalPlan.skip(
        'the input had unreadable records or a rejected one without an id, '
        'so it may be incomplete',
      );
    }
    if (live.isEmpty) return const RemovalPlan.skip('the input is empty');
    return RemovalPlan.remove(live);
  }

  if (batch.issues.any((i) => i.search == null)) {
    return const RemovalPlan.skip(
      'a page that belongs to no planned search could not be read',
    );
  }

  final incomplete = {for (final i in batch.issues) i.search!};
  final seen = <String>{};
  for (final record in batch.records) {
    final id = switch (record.outcome) {
      Mapped(:final listing) => listing.sourceListingId,
      Rejected() => record.liveId,
    };
    if (id != null) {
      seen.add(id);
    } else if (record.search != null) {
      incomplete.add(record.search!);
    } else {
      return const RemovalPlan.skip(
        'a rejected record without an id belongs to no planned search',
      );
    }
  }

  final complete = manifest.fetched.difference(incomplete);
  if (complete.isEmpty || seen.isEmpty) {
    return const RemovalPlan.skip('no search was read in full');
  }
  return RemovalPlan.remove(
    seen.toList(),
    searches: complete.toList()..sort(),
    includeUnkeyed:
        incomplete.isEmpty && manifest.planned.every(complete.contains),
  );
}

const sourceKinds = [
  'manual',
  'standvirtual',
  'standvirtual-search',
  'olx-search',
];

Future<SourceBatch> loadBatch(String kind, String path, Catalog catalog) async {
  switch (kind) {
    case 'manual':
      final adapter = ManualAdapter(path);
      final mapper = ManualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: canonicalListingId(raw.url),
          ),
      ]);
    case 'standvirtual':
      final adapter = StandvirtualPageAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: raw.status == 'ACTIVE'
                ? StandvirtualMapper.listingId(raw.id)
                : null,
          ),
      ]);
    case 'standvirtual-search':
      final adapter = StandvirtualSearchAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(
        adapter.source,
        result.issues,
        [
          for (final (i, raw) in result.records.indexed)
            MappedRecord(
              raw.url,
              mapper.map(raw),
              liveId: raw.status == 'ACTIVE'
                  ? StandvirtualMapper.listingId(raw.id)
                  : null,
              search: result.recordSearches?[i],
            ),
        ],
        manifest: result.manifest,
        siteModels: result.siteModels,
      );
    case 'olx-search':
      final adapter = OlxSearchAdapter(path);
      final mapper = OlxMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(
        adapter.source,
        result.issues,
        [
          for (final (i, raw) in result.records.indexed)
            MappedRecord(
              raw.url,
              mapper.map(raw),
              liveId: raw.status == 'active'
                  ? OlxMapper.listingId(raw.id)
                  : null,
              search: result.recordSearches?[i],
            ),
        ],
        manifest: result.manifest,
        siteModels: result.siteModels,
      );
    default:
      throw ArgumentError('Unknown source "$kind"');
  }
}
