import 'package:supabase/supabase.dart';

import '../../collector.dart';
import 'store_support.dart';

class const StoreResult({
  required final int inserted,
  required final int alreadyStored,
  required final int duplicatesInInput,
});

/// Keeps the first listing for each (source, source id).
List<NormalizedListing> uniqueBySourceId(List<NormalizedListing> listings) {
  final seen = <String>{};
  return [
    for (final l in listings)
      if (seen.add('${l.source}|${l.sourceListingId}')) l,
  ];
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

/// The database id of each catalog entry that has one, by slug.
Map<String, String> _idBySlug(Catalog catalog) => {
  for (final e in catalog.entries)
    if (e.id != null) e.slug: e.id!,
};

/// The database id of [l]'s catalog model; null when it has no model or the
/// catalog entry has no id.
String? motorcycleIdFor(NormalizedListing l, Map<String, String> idBySlug) {
  final slug = l.motorcycleSlug;
  return slug == null ? null : idBySlug[slug];
}

/// The listings themselves: what an import stores and changes, the
/// listing pages' details, then the scores and alerts worked out from them.
class ListingStore(final SupabaseClient _client) {
  /// Live listings of [source] whose listing page has not been read yet,
  /// then those read before the page's photos were kept (`photos_read_at`),
  /// pages that failed before last. Within each, what matters first:
  /// favourites, alerted listings, then by Deal Score (unscored first),
  /// newest first (`listings_missing_details`, R.5), so what waits for the
  /// next run when time runs out is what matters least. Only catalog models
  /// that are not duplicates: details feed the scores, and other listings
  /// are never scored. All of them without a [limit] (the API still
  /// returns at most 1000).
  Future<List<({String sourceListingId, String url})>> listingsMissingDetails(
    String source,
    int? limit,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'listings_missing_details',
      params: {'p_source': source, 'p_limit': limit},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          sourceListingId: r['source_listing_id'] as String,
          url: r['url'] as String,
        ),
    ];
  }

  /// Saves what listing pages added; returns how many listings were updated.
  Future<int> applyDetails(String source, List<ListingDetails> details) async {
    if (details.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'apply_listing_details',
      params: {
        'p_source': source,
        'p_details': [for (final d in details) d.toJson()],
      },
    );
    return rpcCount(result);
  }

  /// Marks listings whose page could not be read, so the next runs try the
  /// others first; returns how many were marked.
  Future<int> markDetailsFailed(String source, List<String> ids) async {
    if (ids.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_details_failed',
      params: {'p_source': source, 'p_ids': ids},
    );
    return rpcCount(result);
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

    final idBySlug = _idBySlug(catalog);

    final rows = <Map<String, Object?>>[];
    for (final l in unique) {
      final slug = l.motorcycleSlug;
      if (slug != null && !idBySlug.containsKey(slug)) {
        throw StateError(
          'Catalog entry "$slug" has no id; load the catalog from Supabase.',
        );
      }
      rows.add(listingRow(l, motorcycleIdFor(l, idBySlug)));
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

  /// Stores the brands and models a site offers (for the app's model
  /// picker), updating the ones already stored. Returns how many.
  Future<int> saveSiteModels(String source, List<SiteModel> models) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = [
      for (final m in uniqueSiteModels(models))
        {...m.toRow(source), 'seen_at': now},
    ];
    for (var i = 0; i < rows.length; i += 500) {
      await _client
          .from('site_models')
          .upsert(
            rows.sublist(i, i + 500 > rows.length ? rows.length : i + 500),
            onConflict: 'source,make_id,model_id',
          );
    }
    return rows.length;
  }

  /// Recomputes the stored deal and risk scores (see `recalculate_deal_scores`).
  Future<int> recalculateScores() async {
    final result = await _client.rpc<Object?>('recalculate_deal_scores');
    return rpcCount(result);
  }

  /// Flags likely duplicates (see `mark_duplicates`); returns how many.
  Future<int> markDuplicates() async {
    final result = await _client.rpc<Object?>('mark_duplicates');
    return rpcCount(result);
  }

  /// Marks listings as seen now (updates last_seen_at); returns how many.
  Future<int> markSeen(String source, List<String> sourceListingIds) async {
    if (sourceListingIds.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_listings_seen',
      params: {'p_source': source, 'p_ids': sourceListingIds},
    );
    return rpcCount(result);
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
    final result = await _client.rpc<Object?>(
      'apply_price_updates',
      params: {'p_source': source, 'p_prices': prices},
    );
    return rpcCount(result);
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
    final result = await _client.rpc<Object?>(
      'apply_prices_before_drop',
      params: {'p_source': source, 'p_prices': prices},
    );
    return rpcCount(result);
  }

  /// Re-checks the model of listings already stored: `save` never updates
  /// a stored row, so without this a wrong match made by an older rule
  /// would stay. Only listings whose model changes are touched; returns how
  /// many.
  Future<int> rematch(
    String source,
    List<NormalizedListing> listings,
    Catalog catalog,
  ) async {
    if (listings.isEmpty) return 0;
    final idBySlug = _idBySlug(catalog);
    final result = await _client.rpc<Object?>(
      'rematch_listings',
      params: {
        'p_source': source,
        'p_matches': {
          for (final l in listings)
            l.sourceListingId: {
              'motorcycle_id': motorcycleIdFor(l, idBySlug),
              'brand': l.brand,
              'model': l.model,
            },
        },
      },
    );
    return rpcCount(result);
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
    final result = await _client.rpc<Object?>(
      'mark_removed_listings',
      params: {
        'p_source': source,
        'p_seen_ids': seenIds,
        'p_max_fraction': force ? 1.0 : 0.5,
        'p_search_keys': searches,
        'p_include_unkeyed': includeUnkeyed,
      },
    );
    return rpcCount(result);
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
    final result = await _client.rpc<Object?>(
      'apply_listing_dates',
      params: {'p_source': source, 'p_dates': dates},
    );
    return rpcCount(result);
  }

  /// Records the search each stored listing was found by; returns how many
  /// changed.
  Future<int> setSearchKeys(String source, Map<String, String> keys) async {
    if (keys.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'set_search_keys',
      params: {'p_source': source, 'p_keys': keys},
    );
    return rpcCount(result);
  }

  /// Creates the alerts that are due (see `generate_alerts`); returns how many.
  Future<int> generateAlerts() async {
    final result = await _client.rpc<Object?>('generate_alerts');
    return rpcCount(result);
  }
}
