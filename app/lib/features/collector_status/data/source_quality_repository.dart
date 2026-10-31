import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/source_quality.dart';

abstract interface class SourceQualityRepository {
  /// One entry per site with live listings.
  Future<List<SourceQuality>> getAll();
}

class SupabaseSourceQualityRepository(final SupabaseClient _client)
    implements SourceQualityRepository {
  @override
  Future<List<SourceQuality>> getAll() async {
    final rows = await _client
        .from('source_data_quality')
        .select()
        .order('source');
    return rows.map(SourceQuality.fromJson).toList();
  }
}
