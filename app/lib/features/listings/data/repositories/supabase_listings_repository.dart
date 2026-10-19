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
  }) async {
    var query = _client.from('listings').select();
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
    };

    final rows = await ordered;
    return rows.map(ListingModel.fromJson).toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    final row = await _client
        .from('listings')
        .select()
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
        .select()
        .or('id.eq.$originalId,duplicate_of.eq.$originalId')
        .neq('id', listing.id)
        .order('first_seen_at');
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
