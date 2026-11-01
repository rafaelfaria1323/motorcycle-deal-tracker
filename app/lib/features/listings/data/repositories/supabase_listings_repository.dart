import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/repositories/listings_repository.dart';
import '../models/first_page_model.dart';
import '../models/listing_model.dart';

class SupabaseListingsRepository(final SupabaseClient _client)
    implements ListingsRepository {
  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) async {
    // Only listings of the account's own models, from its own years
    // (in_my_models; anonymous sessions: every collected model).
    // web/index.html asks for the first page with the default filters
    // and order before the app starts: keep it in step
    // (test/first_page_test.dart).
    final query = _filtered(
      _client.from('listings').select(ListingModel.summaryColumns),
      filters,
    );

    final ordered = switch (sort) {
      ListingSort.newest => query.order('first_seen_at', ascending: false),
      ListingSort.priceAsc => query.order(
        'asking_price',
        ascending: true,
        nullsFirst: false,
      ),
      ListingSort.priceDesc => query.order(
        'asking_price',
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

  /// Ofertas' filters on a query of listings: the account's own models,
  /// no duplicates, then each criterion. Shared by the pages and the count
  /// of new ones, so both see the same list.
  PostgrestFilterBuilder<T> _filtered<T>(
    PostgrestFilterBuilder<T> base,
    ListingFilters filters,
  ) {
    var query = base.eq('in_my_models', true).isFilter('duplicate_of', null);

    if (filters.motorcycleIds.isNotEmpty) {
      query = query.inFilter('motorcycle_id', filters.motorcycleIds);
    }
    if (filters.minYear != null) {
      query = query.gte('year', filters.minYear!);
    }
    if (filters.maxYear != null) {
      query = query.lte('year', filters.maxYear!);
    }
    // asking_price: the price without placeholders under 300 € (null
    // then), so a maximum never matches "1 €" and the price sorts put
    // those last.
    if (filters.minPrice != null) {
      query = query.gte('asking_price', filters.minPrice!);
    }
    if (filters.maxPrice != null) {
      query = query.lte('asking_price', filters.maxPrice!);
    }
    if (filters.maxMileage != null) {
      query = query.lte('mileage', filters.maxMileage!);
    }
    // The computed field `district`: the ad's place looked up in `places`.
    if (filters.district != null) {
      query = query.eq('district', filters.district!);
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
    if (filters.onlyMyColours) {
      query = query.eq('my_colour', true);
    }
    if (filters.activeOnly) {
      query = query.inFilter('status', ['active', 'price_changed']);
    }
    return query;
  }

  @override
  Future<int> countNewSince(
    DateTime since, {
    ListingFilters filters = ListingFilters.empty,
  }) => _filtered(
    _client.from('listings').count(),
    filters,
  ).gt('first_seen_at', since.toUtc().toIso8601String());

  @override
  Future<Listing?> getListingById(String id) async {
    final row = await _client
        .from('listings')
        .select(
          '*, distance_km, my_colour, motorcycles(new_price_reference, new_price_checked_at, '
          'engine_cc_min, engine_cc_max)',
        )
        .eq('id', id)
        .maybeSingle();

    return row == null ? null : ListingModel.fromJson(row);
  }

  @override
  Future<List<MotorcycleOption>> getMotorcycleOptions() async {
    // Also asked by web/index.html (test/first_page_test.dart).
    final rows = await _client
        .from('motorcycles')
        .select('id, brand, model')
        .eq('tracked_by_me', true)
        .order('brand')
        .order('model');

    return rows.map(motorcycleOptionFromJson).toList();
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
    final price = listing.askingPrice;
    if (model == null || price == null) return const [];
    var query = _client
        .from('listings')
        .select(ListingModel.summaryColumns)
        .eq('motorcycle_id', model)
        .inFilter('status', ['active', 'price_changed'])
        .isFilter('duplicate_of', null)
        .neq('id', listing.id)
        // Placeholders ("1 €") are not cheaper bikes.
        .gte('price', minRealPrice)
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
