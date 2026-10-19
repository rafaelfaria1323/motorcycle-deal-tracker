import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/shared_listing_draft.dart';
import '../../domain/repositories/shared_listings_repository.dart';

class SupabaseSharedListingsRepository implements SharedListingsRepository {
  SupabaseSharedListingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> save(SharedListingDraft draft) async {
    final id = await _client.rpc(
      'add_shared_listing',
      params: {
        'p_source': draft.source,
        'p_source_listing_id': draft.sourceListingId,
        'p_url': draft.url,
        'p_motorcycle_id': draft.motorcycleId,
        'p_price': draft.price,
        'p_year': draft.year,
        'p_mileage': draft.mileage,
        'p_location': draft.location,
        'p_seller_type': draft.sellerType,
        'p_description': draft.description,
        'p_images': draft.images,
      },
    );
    return id as String;
  }
}
