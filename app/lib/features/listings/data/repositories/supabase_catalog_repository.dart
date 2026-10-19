import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/catalog_model.dart';
import '../../domain/repositories/catalog_repository.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CatalogModel>> getModels() async {
    final rows = await _client
        .from('motorcycles')
        .select('id, brand, model, min_year, is_active');
    return [
      for (final row in rows)
        CatalogModel(
          id: row['id'] as String,
          brand: row['brand'] as String,
          model: row['model'] as String,
          minYear: row['min_year'] as int,
          isTracked: row['is_active'] as bool,
        ),
    ];
  }

  @override
  Future<void> setTracked(String motorcycleId, {required bool tracked}) async {
    await _client.rpc(
      'set_model_tracked',
      params: {'p_motorcycle_id': motorcycleId, 'p_tracked': tracked},
    );
  }
}
