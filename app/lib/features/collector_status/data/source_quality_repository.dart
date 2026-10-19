import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/source_quality.dart';

abstract interface class SourceQualityRepository {
  /// One entry per site with live listings.
  Future<List<SourceQuality>> getAll();
}

class SupabaseSourceQualityRepository implements SourceQualityRepository {
  SupabaseSourceQualityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SourceQuality>> getAll() async {
    final rows = await _client
        .from('source_data_quality')
        .select()
        .order('source');
    return rows.map(SourceQuality.fromJson).toList();
  }
}
