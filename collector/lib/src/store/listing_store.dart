import 'package:supabase/supabase.dart';

import '../../collector.dart';

class StoreResult {
  const StoreResult({
    required this.inserted,
    required this.alreadyStored,
    required this.duplicatesInInput,
  });

  final int inserted;
  final int alreadyStored;
  final int duplicatesInInput;
}

/// Keeps the first listing for each (source, source id).
List<NormalizedListing> uniqueBySourceId(List<NormalizedListing> listings) {
  final seen = <String>{};
  return [
    for (final l in listings)
      if (seen.add('${l.source}|${l.sourceListingId}')) l,
  ];
}

/// Every row of a query, read [pageSize] rows at a time: the server returns
/// at most that many per request (PostgREST `max_rows`), without saying it
/// cut the rest. [page] reads rows [from] to [to] (inclusive) of a query
/// with a stable order.
Future<List<Map<String, dynamic>>> readAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page, {
  int pageSize = 1000,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var from = 0; ; from += pageSize) {
    final batch = await page(from, from + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) return rows;
  }
}

/// One `listings` row. Columns with database defaults (status, timestamps)
/// and the scores are left out on purpose.
Map<String, Object?> listingRow(NormalizedListing l, String? motorcycleId) {
  return {
    'source': l.source,
    'source_listing_id': l.sourceListingId,
    'url': l.url,
    'motorcycle_id': motorcycleId,
    'brand': l.brand,
    'model': l.model,
    'variant': l.variant,
    'year': l.year,
    'mileage': l.mileage,
    'price': l.price,
    'price_before_drop': l.priceBeforeDrop,
    'seller_type': l.sellerType.name,
    'seller_name': l.sellerName,
    'location': l.location,
    'description': l.description,
    'images': l.images,
  };
}

class ListingStore {
  ListingStore(this._client);

  final SupabaseClient _client;

  /// Live listings of [source] whose listing page has not been read yet,
  /// newest first. Only catalog models that are not duplicates: details
  /// feed the scores, and other listings are never scored.
  Future<List<({String sourceListingId, String url})>> listingsMissingDetails(
    String source,
    int limit,
  ) async {
    final rows = await _client
        .from('listings')
        .select('source_listing_id, url')
        .eq('source', source)
        .isFilter('details_checked_at', null)
        .not('motorcycle_id', 'is', null)
        .isFilter('duplicate_of', null)
        .inFilter('status', ['active', 'price_changed'])
        .order('first_seen_at', ascending: false)
        .limit(limit);
    return [
      for (final r in rows)
        (
          sourceListingId: r['source_listing_id'] as String,
          url: r['url'] as String,
        ),
    ];
  }

  /// Saves what listing pages added; returns how many listings were updated.
  Future<int> applyDetails(String source, List<ListingDetails> details) async {
    if (details.isEmpty) return 0;
    final result = await _client.rpc(
      'apply_listing_details',
      params: {
        'p_source': source,
        'p_details': [for (final d in details) d.toJson()],
      },
    );
    return (result as num).toInt();
  }

  /// Inserts listings that are not stored yet. Existing ones (same source and
  /// source id) are left untouched, so running the same file twice is safe.
  Future<StoreResult> save(
    List<NormalizedListing> listings,
    Catalog catalog,
  ) async {
    final unique = uniqueBySourceId(listings);
    final duplicates = listings.length - unique.length;
    if (unique.isEmpty) {
      return StoreResult(
        inserted: 0,
        alreadyStored: 0,
        duplicatesInInput: duplicates,
      );
    }

    final idBySlug = {
      for (final e in catalog.entries)
        if (e.id != null) e.slug: e.id!,
    };

    final rows = <Map<String, Object?>>[];
    for (final l in unique) {
      final slug = l.motorcycleSlug;
      if (slug != null && !idBySlug.containsKey(slug)) {
        throw StateError(
          'Catalog entry "$slug" has no id; load the catalog from Supabase.',
        );
      }
      rows.add(listingRow(l, slug == null ? null : idBySlug[slug]));
    }

    // Only the rows that were really inserted come back.
    final inserted = await _client
        .from('listings')
        .upsert(
          rows,
          onConflict: 'source,source_listing_id',
          ignoreDuplicates: true,
        )
        .select('id');

    return StoreResult(
      inserted: inserted.length,
      alreadyStored: unique.length - inserted.length,
      duplicatesInInput: duplicates,
    );
  }

  /// Recomputes the stored deal and risk scores (see `recalculate_deal_scores`).
  Future<int> recalculateScores() async {
    final result = await _client.rpc('recalculate_deal_scores');
    return (result as num).toInt();
  }

  /// Flags likely duplicates (see `mark_duplicates`); returns how many.
  Future<int> markDuplicates() async {
    final result = await _client.rpc('mark_duplicates');
    return (result as num).toInt();
  }

  /// Marks listings as seen now (updates last_seen_at); returns how many.
  Future<int> markSeen(String source, List<String> sourceListingIds) async {
    if (sourceListingIds.isEmpty) return 0;
    final result = await _client.rpc(
      'mark_listings_seen',
      params: {'p_source': source, 'p_ids': sourceListingIds},
    );
    return (result as num).toInt();
  }

  /// Applies new prices to listings already stored; returns how many changed.
  Future<int> applyPriceChanges(
    String source,
    List<NormalizedListing> listings,
  ) async {
    if (listings.isEmpty) return 0;
    final prices = <String, num>{
      for (final l in listings) l.sourceListingId: l.price,
    };
    final result = await _client.rpc(
      'apply_price_updates',
      params: {'p_source': source, 'p_prices': prices},
    );
    return (result as num).toInt();
  }

  /// Records what the source says the price was before its last cut (the
  /// database keeps the highest seen); returns how many changed.
  Future<int> applyPricesBeforeDrop(
    String source,
    List<NormalizedListing> listings,
  ) async {
    final prices = <String, num>{
      for (final l in listings) l.sourceListingId: ?l.priceBeforeDrop,
    };
    if (prices.isEmpty) return 0;
    final result = await _client.rpc(
      'apply_prices_before_drop',
      params: {'p_source': source, 'p_prices': prices},
    );
    return (result as num).toInt();
  }

  /// For a complete import: marks live listings missing from [seenIds] as
  /// removed. The database refuses empty or suspiciously large removals unless
  /// [force] is set. Returns how many were marked.
  Future<int> markRemoved(
    String source,
    List<String> seenIds, {
    bool force = false,
    List<String>? searches,
    bool includeUnkeyed = true,
  }) async {
    final result = await _client.rpc(
      'mark_removed_listings',
      params: {
        'p_source': source,
        'p_seen_ids': seenIds,
        'p_max_fraction': force ? 1.0 : 0.5,
        'p_search_keys': searches,
        'p_include_unkeyed': includeUnkeyed,
      },
    );
    return (result as num).toInt();
  }

  /// Stores the publication and renewal dates the source shows; returns how
  /// many listings changed.
  Future<int> applyListingDates(
    String source,
    List<NormalizedListing> listings,
  ) async {
    final dates = <String, Map<String, String?>>{
      for (final l in listings)
        if (l.publishedAt != null || l.siteRefreshedAt != null)
          l.sourceListingId: {
            'published_at': l.publishedAt?.toIso8601String(),
            'site_refreshed_at': l.siteRefreshedAt?.toIso8601String(),
          },
    };
    if (dates.isEmpty) return 0;
    final result = await _client.rpc(
      'apply_listing_dates',
      params: {'p_source': source, 'p_dates': dates},
    );
    return (result as num).toInt();
  }

  /// Records the search each stored listing was found by; returns how many
  /// changed.
  Future<int> setSearchKeys(String source, Map<String, String> keys) async {
    if (keys.isEmpty) return 0;
    final result = await _client.rpc(
      'set_search_keys',
      params: {'p_source': source, 'p_keys': keys},
    );
    return (result as num).toInt();
  }

  /// Creates the alerts that are due (see `generate_alerts`); returns how many.
  Future<int> generateAlerts() async {
    final result = await _client.rpc('generate_alerts');
    return (result as num).toInt();
  }

  /// Alerts of real accounts not pushed yet, oldest first.
  Future<List<PendingAlert>> pendingNotifications({int limit = 20}) async {
    final rows =
        await _client.rpc('pending_notifications', params: {'p_limit': limit})
            as List<dynamic>;
    return [
      for (final row in rows) PendingAlert.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// For the weekly summary: listings of the models in [bikeNames] (id to
  /// name), not duplicates, that are live or were first seen or found
  /// missing since [since].
  Future<List<SummaryListing>> summaryListings(
    Map<String, String> bikeNames,
    DateTime since,
  ) async {
    if (bikeNames.isEmpty) return const [];
    final from = since.toUtc().toIso8601String();
    final rows = await readAllPages(
      (start, end) => _client
          .from('listings')
          .select(
            'id, motorcycle_id, brand, model, url, status, first_seen_at, '
            'last_checked_at, year, mileage, price, deal_score, risk_score',
          )
          .inFilter('motorcycle_id', bikeNames.keys.toList())
          .isFilter('duplicate_of', null)
          .or(
            'status.in.(active,price_changed),'
            'first_seen_at.gte."$from",last_checked_at.gte."$from"',
          )
          .order('id')
          .range(start, end),
    );
    return [for (final r in rows) SummaryListing.fromRow(r, bikeNames)];
  }

  /// The whole price history of those of [listingIds] whose price was
  /// recorded since [since] (a new price, or a new listing's first one).
  Future<List<PricePoint>> priceHistoryChangedSince(
    Set<String> listingIds,
    DateTime since,
  ) async {
    final recent = await readAllPages(
      (start, end) => _client
          .from('listing_price_history')
          .select('listing_id')
          .gte('observed_at', since.toUtc().toIso8601String())
          .order('id')
          .range(start, end),
    );
    final ids = {
      for (final r in recent)
        if (listingIds.contains(r['listing_id'])) r['listing_id'] as String,
    }.toList();

    final points = <PricePoint>[];
    // A few ids per request keep the address short.
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, (i + 100).clamp(0, ids.length));
      final rows = await readAllPages(
        (start, end) => _client
            .from('listing_price_history')
            .select('listing_id, price, observed_at')
            .inFilter('listing_id', chunk)
            .order('id')
            .range(start, end),
      );
      points.addAll([for (final r in rows) PricePoint.fromRow(r)]);
    }
    return points;
  }

  Future<int> markNotified(List<String> alertIds) async {
    if (alertIds.isEmpty) return 0;
    final result = await _client.rpc(
      'mark_alerts_notified',
      params: {'p_ids': alertIds},
    );
    return (result as num).toInt();
  }
}
