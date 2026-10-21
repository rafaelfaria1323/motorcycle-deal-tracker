import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/dealer_reliability.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../models/dealer_reliability_model.dart';

class SupabaseDealerRepository implements DealerRepository {
  SupabaseDealerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DealerReliability?> getByName(String sellerName) async {
    final row = await _client
        .from('dealer_reliability')
        .select()
        .eq('dealer_key', dealerKey(sellerName))
        .maybeSingle();
    return row == null ? null : dealerFromJson(row);
  }
}
