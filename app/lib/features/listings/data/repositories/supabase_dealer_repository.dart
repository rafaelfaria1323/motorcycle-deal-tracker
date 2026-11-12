import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dealer_reliability.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../models/dealer_reliability_model.dart';
import '../models/listing_model.dart';

class SupabaseDealerRepository(final SupabaseClient _client)
    implements DealerRepository {
  @override
  Future<DealerReliability?> getByName(String sellerName) async {
    final row = await _client
        .from('dealer_reliability')
        .select()
        .eq('dealer_key', dealerKey(sellerName))
        .maybeSingle();
    return row == null ? null : dealerFromJson(row);
  }

  @override
  Future<List<Listing>> getListings(String sellerName) async {
    final rows = await _client
        .rpc<Object?>('dealer_listings', params: {'p_name': sellerName})
        .select(ListingModel.summaryColumns);
    return rows.map<Listing>(ListingModel.fromJson).toList();
  }
}
