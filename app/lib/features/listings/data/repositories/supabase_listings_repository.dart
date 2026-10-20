import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/repositories/listings_repository.dart';
import '../models/listing_model.dart';

class SupabaseListingsRepository implements ListingsRepository {
  SupabaseListingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) async {
    // Only listings of tracked models: switched-off models' listings are
    // no longer checked, and unmatched ones have no score.
    var query = _client
        .from('listings')
        .select('${ListingModel.summaryColumns}, motorcycles!inner(is_active)')
        .eq('motorcycles.is_active', true);
    query = query.isFilter('duplicate_of', null);

    if (filters.motorcycleId != null) {
      query = query.eq('motorcycle_id', filters.motorcycleId!);
    }
    if (filters.minYear != null) {
      query = query.gte('year', filters.minYear!);
    }
    if (filters.maxPrice != null) {
      query = query.lte('price', filters.maxPrice!);
    }
    if (filters.maxMileage != null) {
      query = query.lte('mileage', filters.maxMileage!);
    }
    if (filters.location != null) {
      query = query.ilike('location', '%${filters.location}%');
    }
    if (filters.sellerType != null) {
      query = query.eq('seller_type', filters.sellerType!.name);
    }
    if (filters.minDealScore != null) {
      query = query.gte('deal_score', filters.minDealScore!);
    }
    if (filters.maxRiskScore != null) {
      query = query.lte('risk_score', filters.maxRiskScore!);
    }
    if (filters.maxDistanceKm != null) {
      query = query.lte('distance_km', filters.maxDistanceKm!);
    }
    if (filters.extras.isNotEmpty) {
      // jsonb containment: the ad mentions every one of them.
      query = query.filter(
        'score_breakdown->extras',
        'cs',
        jsonEncode(filters.extras),
      );
    }
    if (filters.activeOnly) {
      query = query.inFilter('status', ['active', 'price_changed']);
    }

    final ordered = switch (sort) {
      ListingSort.newest => query.order('first_seen_at', ascending: false),
      ListingSort.priceAsc => query.order(
        'price',
        ascending: true,
        nullsFirst: false,
      ),
      ListingSort.priceDesc => query.order(
        'price',
        ascending: false,
        nullsFirst: false,
      ),
      ListingSort.dealScoreDesc => query.order(
        'deal_score',
        ascending: false,
        nullsFirst: false,
      ),
      ListingSort.nearest => query.order(
        'distance_km',
        ascending: true,
        nullsFirst: false,
      ),
    };

    // The id breaks ties, so pages never repeat or skip a listing.
    final rows = await ordered.order('id').range(offset, offset + limit - 1);
    return rows.map(ListingModel.fromJson).toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    final row = await _client
        .from('listings')
        .select(
          '*, distance_km, motorcycles(new_price_reference, new_price_checked_at, '
          'engine_cc_min, engine_cc_max)',
        )
        .eq('id', id)
        .maybeSingle();

    return row == null ? null : ListingModel.fromJson(row);
  }

  @override
  Future<List<MotorcycleOption>> getMotorcycleOptions() async {
    final rows = await _client
        .from('motorcycles')
        .select('id, brand, model')
        .eq('is_active', true)
        .order('brand')
        .order('model');

    return rows
        .map(
          (row) => MotorcycleOption(
            id: row['id'] as String,
            brand: row['brand'] as String,
            model: row['model'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<Listing>> getAlsoListed(Listing listing) async {
    final originalId = listing.duplicateOf ?? listing.id;
    final rows = await _client
        .from('listings')
        .select(ListingModel.summaryColumns)
        .or('id.eq.$originalId,duplicate_of.eq.$originalId')
        .neq('id', listing.id)
        .order('first_seen_at');
    return rows.map<Listing>(ListingModel.fromJson).toList();
  }

  @override
  Future<List<Listing>> getCheaperSimilar(Listing listing) async {
    final model = listing.motorcycleId;
    final price = listing.price;
    if (model == null || price == null) return const [];
    var query = _client
        .from('listings')
        .select(ListingModel.summaryColumns)
        .eq('motorcycle_id', model)
        .inFilter('status', ['active', 'price_changed'])
        .isFilter('duplicate_of', null)
        .neq('id', listing.id)
        .lt('price', price);
    if (listing.year case final year?) {
      query = query.gte('year', year - 1).lte('year', year + 1);
    }
    if (listing.mileage case final km?) {
      query = query.lte('mileage', km);
    }
    final rows = await query.order('price').limit(3);
    return rows.map<Listing>(ListingModel.fromJson).toList();
  }

  @override
  Future<List<PricePoint>> getPriceHistory(String listingId) async {
    final rows = await _client
        .from('listing_price_history')
        .select('price, observed_at')
        .eq('listing_id', listingId)
        .order('observed_at');
    return [
      for (final r in rows)
        PricePoint(
          price: (r['price'] as num).toDouble(),
          observedAt: DateTime.parse(r['observed_at'] as String).toLocal(),
        ),
    ];
  }
}
