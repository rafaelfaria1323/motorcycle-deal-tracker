import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing.dart';
import '../../domain/repositories/listings_repository.dart';
import '../models/listing_model.dart';

class SupabaseListingsRepository implements ListingsRepository {
  SupabaseListingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Listing>> getListings({String? motorcycleId}) async {
    var query = _client.from('listings').select();

    if (motorcycleId != null) {
      query = query.eq('motorcycle_id', motorcycleId);
    }

    final rows = await query.order('first_seen_at', ascending: false);
    return rows.map(ListingModel.fromJson).toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    final row = await _client.from('listings').select().eq('id', id).maybeSingle();

    return row == null ? null : ListingModel.fromJson(row);
  }
}
