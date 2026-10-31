import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/catalog_model.dart';
import '../../domain/entities/site_model.dart';
import '../../domain/repositories/catalog_repository.dart';

class SupabaseCatalogRepository(final SupabaseClient _client)
    implements CatalogRepository {
  @override
  Future<List<CatalogModel>> getModels() async {
    final rows = await _client
        .from('motorcycles')
        .select(
          'id, brand, model, my_min_year, tracked_by_me, is_active, '
          'my_colours, olx_search, standvirtual_search, new_price_reference, '
          'new_price_checked_at',
        );
    return [
      for (final row in rows)
        CatalogModel(
          id: row['id'] as String,
          brand: row['brand'] as String,
          model: row['model'] as String,
          minYear: row['my_min_year'] as int,
          isTracked: row['tracked_by_me'] as bool,
          isCollected: row['is_active'] as bool,
          colours: List<String>.from(row['my_colours'] as List? ?? const []),
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
    await _client.rpc<Object?>(
      'set_model_tracked',
      params: {'p_motorcycle_id': motorcycleId, 'p_tracked': tracked},
    );
  }

  @override
  Future<void> setMinYear(String motorcycleId, int minYear) async {
    await _client.rpc<Object?>(
      'set_model_min_year',
      params: {'p_motorcycle_id': motorcycleId, 'p_min_year': minYear},
    );
  }

  @override
  Future<void> setColours(String motorcycleId, List<String> colours) async {
    await _client.rpc<Object?>(
      'set_model_colours',
      params: {'p_motorcycle_id': motorcycleId, 'p_colours': colours},
    );
  }

  @override
  Future<void> setNewPrice(String motorcycleId, double? price) async {
    await _client.rpc<Object?>(
      'set_model_new_price',
      params: {'p_motorcycle_id': motorcycleId, 'p_price': price},
    );
  }

  @override
  Future<List<SiteMake>> getSiteMakes() async {
    final rows = await _client
        .from('site_makes')
        .select('make_id, make_name, ads');
    return [
      for (final row in rows)
        SiteMake(
          id: row['make_id'] as String,
          name: row['make_name'] as String,
          ads: (row['ads'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<List<SiteModel>> getSiteModels(String makeId) async {
    final rows = await _client
        .from('site_models')
        .select('source, make_id, model_id, model_name, ads')
        .eq('make_id', makeId);
    return [
      for (final row in rows)
        SiteModel(
          source: row['source'] as String,
          makeId: row['make_id'] as String,
          id: row['model_id'] as String,
          name: row['model_name'] as String,
          ads: (row['ads'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<void> addModel({
    required String brand,
    required String model,
    required int minYear,
    String? olxSearch,
    String? standvirtualSearch,
    List<String> aliases = const [],
    int? engineCcMin,
    int? engineCcMax,
  }) async {
    await _client.rpc<Object?>(
      'add_catalog_model',
      params: {
        'p_brand': brand,
        'p_model': model,
        'p_min_year': minYear,
        'p_olx_search': olxSearch,
        'p_standvirtual_search': standvirtualSearch,
        'p_aliases': aliases,
        'p_engine_cc_min': engineCcMin,
        'p_engine_cc_max': engineCcMax,
      },
    );
  }
}
