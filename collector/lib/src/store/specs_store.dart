import 'package:supabase/supabase.dart';

import '../specs/model_specs.dart';

/// The catalog side of the specification step (N.76).
class SpecsStore(final SupabaseClient _client) {
  /// The models to look up (`model_specs_to_check`): never asked, or
  /// missing a figure and not asked for [days] days.
  Future<List<SpecsModel>> modelsToCheck(int days) async {
    final rows = await _client.rpc<List<dynamic>>(
      'model_specs_to_check',
      params: {'p_days': days},
    );
    return [
      for (final r in rows) SpecsModel.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Fills [model]'s empty figures with [specs] and stamps it as asked
  /// (`store_model_specs`); the names of the figures filled.
  Future<List<String>> store(String model, ModelSpecs specs) async {
    final filled = await _client.rpc<List<dynamic>>(
      'store_model_specs',
      params: {'p_id': model, 'p_specs': specs.toJson()},
    );
    return [for (final f in filled) '$f'];
  }
}
