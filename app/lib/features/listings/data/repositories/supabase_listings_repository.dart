import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing.dart';
import '../../domain/repositories/listings_repository.dart';
import '../models/listing_model.dart';

class SupabaseListingsRepository implements ListingsRepository {
  SupabaseListingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Listing>> getListings() async {
    final rows = await _client
        .from('listings')
        .select()
        .order('first_seen_at', ascending: false);

    return rows.map(ListingModel.fromJson).toList();
  }
}