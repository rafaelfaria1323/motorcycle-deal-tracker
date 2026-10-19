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
        .select(
          'id, brand, model, min_year, is_active, olx_search, '
          'standvirtual_search, new_price_reference, new_price_checked_at',
        );
    return [
      for (final row in rows)
        CatalogModel(
          id: row['id'] as String,
          brand: row['brand'] as String,
          model: row['model'] as String,
          minYear: row['min_year'] as int,
          isTracked: row['is_active'] as bool,
          olxSearch: row['olx_search'] as String?,
          standvirtualSearch: row['standvirtual_search'] as String?,
          newPrice: (row['new_price_reference'] as num?)?.toDouble(),
          newPriceCheckedAt: row['new_price_checked_at'] is String
              ? DateTime.tryParse(row['new_price_checked_at'] as String)
              : null,
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

  @override
  Future<void> setMinYear(String motorcycleId, int minYear) async {
    await _client.rpc(
      'set_model_min_year',
      params: {'p_motorcycle_id': motorcycleId, 'p_min_year': minYear},
    );
  }

  @override
  Future<void> setNewPrice(String motorcycleId, double? price) async {
    await _client.rpc(
      'set_model_new_price',
      params: {'p_motorcycle_id': motorcycleId, 'p_price': price},
    );
  }

  @override
  Future<void> addModel({
    required String brand,
    required String model,
    required int minYear,
    String? olxSearch,
    String? standvirtualSearch,
    List<String> aliases = const [],
  }) async {
    await _client.rpc(
      'add_catalog_model',
      params: {
        'p_brand': brand,
        'p_model': model,
        'p_min_year': minYear,
        'p_olx_search': olxSearch,
        'p_standvirtual_search': standvirtualSearch,
        'p_aliases': aliases,
      },
    );
  }
}
