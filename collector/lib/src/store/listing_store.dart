import 'package:supabase/supabase.dart';

import '../catalog/catalog.dart';
import '../normalized/normalized_listing.dart';

class StoreResult {
  const StoreResult({required this.inserted, required this.alreadyStored, required this.duplicatesInInput});

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

  /// Inserts listings that are not stored yet. Existing ones (same source and
  /// source id) are left untouched, so running the same file twice is safe.
  Future<StoreResult> save(List<NormalizedListing> listings, Catalog catalog) async {
    final unique = uniqueBySourceId(listings);
    final duplicates = listings.length - unique.length;
    if (unique.isEmpty) {
      return StoreResult(inserted: 0, alreadyStored: 0, duplicatesInInput: duplicates);
    }

    final idBySlug = {
      for (final e in catalog.entries)
        if (e.id != null) e.slug: e.id!,
    };

    final rows = <Map<String, Object?>>[];
    for (final l in unique) {
      final slug = l.motorcycleSlug;
      if (slug != null && !idBySlug.containsKey(slug)) {
        throw StateError('Catalog entry "$slug" has no id; load the catalog from Supabase.');
      }
      rows.add(listingRow(l, slug == null ? null : idBySlug[slug]));
    }

    // Only the rows that were really inserted come back.
    final inserted = await _client
        .from('listings')
        .upsert(rows, onConflict: 'source,source_listing_id', ignoreDuplicates: true)
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
}
